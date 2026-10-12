# Terraform Generator

Turns an infrastructure spec (YAML) into a plain `azurerm` Terraform configuration. It does no interpretation: the same spec always produces byte-identical files.

```powershell
./New-TerraformConfiguration.ps1 -SpecPath ./examples/work-item-service/work-item-service.infra.yaml -OutputPath ./out
```

Requirements: PowerShell 7 and the `powershell-yaml` module (`Install-Module powershell-yaml -Scope CurrentUser`). Terraform 1.6 or later (or OpenTofu) is needed to use the output, not to generate it.

## What you get

```
out/
  providers.tf      terraform block, azurerm 4.x provider, partial azurerm backend
  variables.tf      environment, plus one variable per value that differs by environment
  locals.tf         naming parts, tags, and every resource name
  main.tf           the resources, role assignments and diagnostic settings
  outputs.tf        names, URLs and endpoints
  environments/
    dev.tfvars   dev.backend.hcl
    qa.tfvars    qa.backend.hcl
    prd.tfvars   prd.backend.hcl
```

Use one environment at a time:

```powershell
terraform init -backend-config=environments/dev.backend.hcl
terraform plan -var-file=environments/dev.tfvars
```

Set `ARM_SUBSCRIPTION_ID` to the subscription for that environment. Replace the `REPLACE_WITH_...` state values in the spec first; the platform team owns them.

## How it works

| Piece | Job |
|---|---|
| `New-TerraformConfiguration.ps1` | The orchestrator. Reads and validates the spec, runs each action, writes the files. |
| `Actions/` | One script per resource type. Each one returns the Terraform for a resource of that type. `RoleAssignments.ps1` and `DiagnosticSettings.ps1` handle `access:` and `diagnostics:`. |
| `Private/` | Shared helpers: HCL formatting, the resource-type table, spec validation, file output. |
| `schema/infra-spec.schema.json` | Structural validation of the spec. |
| `docs/infra-spec-reference.md` | How to write a spec. |
| `tests/Test-Generator.ps1` | Determinism, coverage, validation and formatting checks. |

Generated HCL is already in `terraform fmt` layout, so no formatting step is needed.

## Check it

```powershell
./tests/Test-Generator.ps1
```

## Provider arguments to confirm

The generated Terraform has been formatted with `tofu fmt`, but it has not been run through `terraform validate` or `plan` against the real azurerm provider. Before the first apply, run `terraform init` and `terraform validate`, and confirm these arguments against the provider version in use:

- `azurerm_function_app_flex_consumption`: the runtime version value (`10.0`) and the instance memory and maximum instance count values it accepts.
- `azurerm_app_configuration`: that `developer` is an accepted `sku`.
- `azurerm_monitor_diagnostic_setting`: `enabled_metric` (older provider versions use `metric`).
- `azurerm_cosmosdb_sql_container`: `partition_key_paths` (older versions use `partition_key_path`).
- `azurerm_servicebus_subscription_rule`: Service Bus creates a default rule that accepts every message when a subscription is created. Confirm the filtered `notifications` subscription ends up with only the SQL filter, and delete the default rule if it remains.
- Ordering: the Function App's identity needs the Storage Blob Data Owner role on its host storage account. If the first apply fails reading the deployment container, apply again once the role assignment exists.
