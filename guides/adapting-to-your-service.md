# Adapting This to Your Service

The Work Item Service is the worked example. The approach carries over to your own services: write infrastructure architecture a person can review, let AI turn it into a structured spec, and let a script generate the Terraform. This guide covers what to change, what to keep, and where the limits are.

## What carries over and what does not

| Reuse as is | Change for your service |
|---|---|
| The workflow: documents, then spec, then Terraform | The architecture documents in `docs/` |
| The generator, its schema and its tests | The prompt, if your documents are organized differently |
| The spec format | The spec itself, which AI writes from your documents |
| The review habit: assumptions, questions, plan | Anything your service needs that the generator does not support yet |

## 1. Write the infrastructure architecture so it can be interpreted

The quality of the spec depends on the quality of the document. The example `docs/infrastructure-architecture-guide.md` is the model. These are the features that made it work:

- **A mapping table.** Section 5.1 lists every part of the service, the infrastructure it needs, and the resource type to use in the spec. If a reader (or an AI) can find every resource in one table, nothing gets missed.
- **Numbered obligations.** Each rule has an ID, a statement and a class such as MUST or TARGET. IDs let the spec point back to the reason for each setting.
- **Concrete baselines.** Settings are given as values with units: "message time-to-live 7 days", "0.5 vCPU and 1 GiB memory". Avoid "small" or "standard".
- **Naming and tagging in one place.** One pattern, one tag table.
- **A table of environment differences.** List what differs between environments, and say plainly that everything else is the same.
- **A clear boundary.** Say what is provisioned by this service and what is external, such as a shared container registry or the Terraform state location. Without it, an AI will try to build everything it reads about.
- **Deferred decisions marked as such.** If a decision is open, say who owns it and when it must be made. An AI that finds a gap should report it, not fill it with a guess, and the document should make that easy.

If your organization already has architecture templates, keep them. The only requirement is that the infrastructure document contains the items above, in any layout.

## 2. Check what the generator supports

The generator supports the resource types in the [spec reference](../tools/terraform-generator/docs/infra-spec-reference.md): resource group, Log Analytics, Application Insights, App Configuration, Key Vault, Service Bus (namespace, topic, subscription), storage account, Cosmos DB (account, SQL database, SQL container), Container Apps (environment, app) and Function Apps on Flex Consumption.

Compare it with section 5.1 of your guide. If you need something that is not on the list, see [Extending the generator](extending-the-generator.md). A new resource type is one script, one schema entry and one table row.

Some choices are built in and worth knowing before you adopt the generator:

- A single region, East US 2.
- The `azurerm` provider, version 4.x, with plain resources and no modules.
- Security defaults are fixed by the generator, not set in the spec: local authentication disabled where the platform allows it, managed identities, role-based access control for Key Vault. The reference lists them under "What the generator decides". If your standards differ, change the action scripts.
- Names follow the pattern in the example guide. To change the pattern, edit `Get-NameHcl` in `Private/Spec.ps1`.

## 3. Adapt the prompt

Copy the prompt and edit the copy. The GitHub Copilot version is `.github/prompts/create-infrastructure-spec.prompt.md` and the Claude Code version is `.claude/skills/create-infrastructure-spec/SKILL.md`. They carry the same instructions with different frontmatter, so if you use both tools, make each change in both. It does not hard-code the service name, and it derives it from your documents. What you may need to change:

- **File names and sections.** The prompt lists the files to read and the guide sections that hold each kind of information. Update these to match your documents.
- **Rules.** Add rules that reflect your organization, such as required tags or naming exceptions.
- **The output path.** The default is `infra/<service-name>.infra.yaml`.

Keep the parts that make the output reviewable: the instruction not to invent values, the comment above each resource naming its source, and the closing request for a traceability table, assumptions and questions.

## 4. Review the spec like code

AI writes the spec and a person approves it. A good review looks at:

- **Assumptions and questions.** Resolve each one by fixing the document or accepting the AI's choice. If the AI had to guess, the document was unclear, so fix it there as well and generate again next time.
- **Coverage.** Every row of the mapping table should appear in the spec, and nothing extra should.
- **Per-environment values.** Compare them with your table of environment differences.
- **The remote state placeholders.** Someone must supply the real values.

Then commit the spec. From this point the spec is the source of truth for the infrastructure, and the generated Terraform is a build output.

## 5. Generate, check and plan

Run the generator, then `terraform init`, `validate`, `tflint` and `plan` as in the README. The generator also runs its own checks first, so mistakes in the spec fail early with a readable message.

Two practices make this safe to rely on:

- **Generate in your pipeline and fail on a diff.** Because output is byte-identical for the same spec, a pipeline can regenerate and compare with what is committed. A difference means someone changed the spec without regenerating, or edited generated files by hand.
- **Do not edit generated files.** Change the spec, or change the generator, and generate again. Hand edits are lost the next time the generator runs.

## Things to confirm before relying on it

The generated Terraform passes `fmt`, `validate` and `plan` in the example, but treat any new resource type, provider version or setting as unproven until you have run it. The [generator README](../tools/terraform-generator/README.md#provider-arguments-to-confirm) lists the provider arguments worth confirming. Apply to a non-production subscription first.
