---
agent: agent
description: Read the approved architecture documents and write the infrastructure spec (YAML) the Terraform generator consumes.
---

# Create the infrastructure spec

You are a platform engineer. The service's architecture is approved. Your job is to turn the approved Infrastructure Architecture Guide into the companion infrastructure spec, `{service-name}.infra.yaml`. A PowerShell generator turns that file into Terraform, so the spec must be exact and must say only what the documents say.

## Read these first

1. `docs/infrastructure-architecture-guide.md`. This is the source of truth for the spec. Work through sections 5.1, 6.1, 6.2, 6.3, 6.7 and 7 in particular.
2. `tools/terraform-generator/docs/infra-spec-reference.md`. This defines the spec format: every resource type, field, allowed value and reference.
3. `tools/terraform-generator/schema/infra-spec.schema.json`. The spec must validate against it.
4. `docs/architecture-specifications.md`, `docs/system-context.md` and `docs/architecture-guide.md`, only to resolve questions the Infrastructure Architecture Guide leaves open.

Do not read or copy anything under `tools/terraform-generator/examples/`, and do not look at any existing `.infra.yaml` file. Build the spec from the documents.

## What to produce

Write one file: `infra/{service-name}.infra.yaml`, creating the `infra` folder if it does not exist.

Work out `{service-name}` from the architecture documents; do not assume it. The Infrastructure Architecture Guide gives the service's name in its front matter (`service_name`) and its title. Write it in lower-case kebab-case (for example, "Order Tracking Service" becomes `order-tracking-service`) and use that same value for the spec's `service:` field and in the file name. If the documents name the service inconsistently, use the Infrastructure Architecture Guide's name and list the inconsistency under "Questions for a human".

- Create one `resources:` entry for every row of the section 5.1 table whose provisioning responsibility is "New". Skip rows marked External or "Outside infrastructure scope"; those are not provisioned by this service.
- Take every setting from the guide: sections 6.1 and 6.2 for configuration, section 6.3 for the `access:` list, section 6.7 for `organization`, `workload`, `region_abbreviation` and `tags`, and section 7 for every value that differs by environment. Use the per-environment `{ dev: .., qa: .., prd: .. }` form only for fields the reference says can vary, and only where section 7 gives different values.
- Convert units to the formats the reference asks for (for example, 7 days becomes `P7D`, 10 minutes becomes `PT10M`, 1 GiB becomes `1Gi`).
- Use `from:` references for application settings that come from another resource, as the reference describes.
- Add `diagnostics: true` to each resource the guide says sends logs and metrics to the workspace (IG-012).
- Terraform remote state is supplied by Platform Engineering (IG-021). Set all three `state:` values to placeholders that start with `REPLACE_WITH_`.
- Add a short YAML comment above each resource naming the guide section or obligation ID (for example `# IG-007, section 6.2`) so a reviewer can trace it back.

## Rules

- Do not invent values. If the documents do not state something the spec requires, choose the most conservative value the reference allows, and list it under "Assumptions" below.
- Do not add resources, settings or role assignments the guide does not call for.
- Do not put security settings in the spec that the generator fixes itself (the reference lists them under "What the generator decides").
- Keep the file to the spec only. Do not create Terraform and do not run the generator; that is the next step.

## When you are done

Reply with:

1. A traceability table: each section 5.1 row, the spec entry it became, and the IG obligation IDs it satisfies.
2. **Assumptions**: anything you had to decide because the documents were silent, one line each. Write "None" if there are none.
3. **Questions for a human**: anything ambiguous or inconsistent between documents. Write "None" if there are none.
