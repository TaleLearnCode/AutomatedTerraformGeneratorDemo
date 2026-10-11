# Infrastructure Spec Reference

The infrastructure spec is the single input to `New-TerraformConfiguration.ps1`. It is a YAML file that lists the Azure resources a service needs and the few values that differ between environments. Everything else (names, tags, security settings, identities, role assignments) is decided by the generator, so the same spec always produces the same Terraform.

The machine-readable definition is [`schema/infra-spec.schema.json`](../schema/infra-spec.schema.json). A worked example is [`examples/work-item-service/work-item-service.infra.yaml`](../examples/work-item-service/work-item-service.infra.yaml).

## File layout

```yaml
spec_version: 1
service: work-item-service
organization: mmtm
workload: wis
region: eastus2
region_abbreviation: eus2
environments: [dev, qa, prd]
tags: { ... }
state: { ... }
resources: [ ... ]
access: [ ... ]
```

| Field | Meaning |
|---|---|
| `spec_version` | Always `1`. |
| `service` | Service name. Used in the remote state key (`<service>-<environment>.tfstate`). |
| `organization`, `workload` | The `{org}` and `{workload}` parts of every resource name. |
| `region`, `region_abbreviation` | Azure region and the short form used in names. Only `eastus2` is supported. |
| `environments` | Environment names. Each one gets `environments/<name>.tfvars` and `.backend.hcl`. |
| `tags` | Tags for every resource. Do not add `environment`; the generator adds it. |
| `state` | Remote state location for the `azurerm` backend. Supplied by the platform team. |
| `resources` | The resources to build (below). |
| `access` | Which managed identity gets which role on what (below). |

## Per-environment values

A field that can differ between environments takes either one value or a value for every environment:

```yaml
retention_in_days: 30                              # same everywhere
retention_in_days: { dev: 30, qa: 30, prd: 90 }    # differs
```

The generator turns a per-environment value into a Terraform variable and writes each environment's value into its `.tfvars` file. Only these fields can differ; anything else is an architecture decision that must be the same everywhere.

| Resource type | Fields |
|---|---|
| `log_analytics_workspace` | `retention_in_days` |
| `app_configuration` | `sku` |
| `key_vault` | `purge_protection` |
| `cosmosdb_account` | `backup_retention_days` |
| `container_app` | `min_replicas`, `max_replicas` |
| `function_app` | `max_instance_count` |

A map must list every environment, and no others.

## Resources

Each entry has a `type`. Types marked "key" also need a `key` that names the instance. Resources that exist once per environment have no key.

| `type` | Key | Becomes | Fields |
|---|---|---|---|
| `resource_group` | | `azurerm_resource_group` | none |
| `log_analytics_workspace` | | `azurerm_log_analytics_workspace` | `retention_in_days` (required) |
| `application_insights` | | `azurerm_application_insights` | none; workspace-based, linked to the workspace |
| `app_configuration` | | `azurerm_app_configuration` | `sku` (required: `developer`, `standard`, `premium`) |
| `key_vault` | | `azurerm_key_vault` | `purge_protection` (required), `soft_delete_retention_days` (default 90), `diagnostics` |
| `servicebus_namespace` | | `azurerm_servicebus_namespace` | `sku` (default `Standard`), `minimum_tls_version` (default `1.2`), `diagnostics` |
| `servicebus_topic` | key | `azurerm_servicebus_topic` | `default_message_ttl` (required, ISO 8601), `duplicate_detection_window` |
| `servicebus_subscription` | key | `azurerm_servicebus_subscription` (+ `_rule` when `filter` is set) | `topic`, `max_delivery_count`, `lock_duration`, `default_message_ttl`, `dead_letter_on_expiration` (all required), `filter: { name, sql }` |
| `storage_account` | | `azurerm_storage_account` + one `azurerm_storage_container` per entry | `containers` (required), `replication_type` (default `LRS`), `access_tier` (default `Hot`) |
| `cosmosdb_account` | | `azurerm_cosmosdb_account` | `capacity_mode` (`serverless`), `consistency_level`, `backup_retention_days` (7 or 30), `diagnostics` (all but `diagnostics` required) |
| `cosmosdb_sql_database` | key | `azurerm_cosmosdb_sql_database` | none |
| `cosmosdb_sql_container` | key | `azurerm_cosmosdb_sql_container` | `database`, `partition_key_path` (required), `unique_key_paths` |
| `container_app_environment` | | `azurerm_container_app_environment` | none; Consumption profile, logs to the workspace |
| `container_app` | key | `azurerm_container_app` | `image`, `cpu`, `memory`, `target_port`, `min_replicas`, `max_replicas`, `http_concurrency` (required), `settings` |
| `function_app` | key | `azurerm_service_plan` (FC1) + `azurerm_function_app_flex_consumption` | `runtime`, `runtime_version`, `instance_memory_mb`, `max_instance_count`, `deployment_container` (required), `settings` |

`diagnostics: true` sends all log categories and all metrics to the Log Analytics workspace.

### Settings

`container_app` and `function_app` take a list of application settings. Each is a literal `value` or a `from` reference to another resource:

```yaml
settings:
  - { name: FEATURE_FLAG, value: "on" }
  - { name: APPCONFIG_ENDPOINT, from: app_configuration.endpoint }
```

| `from` | Resolves to |
|---|---|
| `app_configuration.endpoint` | App Configuration endpoint |
| `key_vault.uri` | Key Vault URI |
| `application_insights.connection_string` | Application Insights connection string |
| `cosmosdb_account.endpoint` | Cosmos DB account endpoint |
| `servicebus_namespace.fully_qualified_namespace` | `<namespace>.servicebus.windows.net` |
| `storage_account.name` | Storage account name |

## Access

Each entry grants one managed identity one role on one resource. The principal is a `container_app` or `function_app`; the scope is any resource type the role supports.

```yaml
access:
  - { principal: container_app/api, role: Azure Service Bus Data Sender, scope: servicebus_topic/work-item-events }
```

| Role | Allowed scope types |
|---|---|
| Azure Service Bus Data Sender / Receiver | `servicebus_topic`, `servicebus_namespace` |
| App Configuration Data Reader | `app_configuration` |
| Key Vault Secrets User | `key_vault` |
| Storage Blob Data Owner | `storage_account` |
| Cosmos DB Built-in Data Contributor | `cosmosdb_sql_database` (data-plane role) |

Use `type/key` for keyed resources and just `type` for the rest (for example `scope: key_vault`).

## What the generator decides

These are fixed by the generator, not set in the spec. They implement the Infrastructure Architecture Guide obligations noted in brackets.

- Names follow `{abbreviation}-{org}-{workload}[-{key}]-{environment}-{region_abbreviation}`; the storage account omits hyphens [IG-001].
- Every resource is in East US 2 and carries the spec tags plus `environment` [IG-002, IG-003].
- Local authentication is disabled on Service Bus, App Configuration and Cosmos DB, and shared key access is disabled on storage [IG-008].
- Container Apps and Function Apps use a system-assigned managed identity [IG-009]. The container app has HTTPS-only external ingress and a single active revision [IG-005]; its image is ignored after creation because the pipeline replaces it [IG-020].
- Key Vault uses role-based access control [IG-010].

## Validation

The generator checks the spec before writing anything. It stops with a list of problems if a field is misspelled or the wrong type, a reference points at something that is not in the spec (a subscription's `topic`, a container's `database`, a role's scope), a per-environment map is incomplete, or a role is scoped to a type it does not support.

## Adding a resource type

1. Add a row to `Private/ResourceTypes.ps1`.
2. Add `Actions/<PascalCaseType>.ps1` defining `New-<PascalCaseType>Hcl`, which returns the Terraform for one resource.
3. Add the type to `schema/infra-spec.schema.json`.
4. If it needs another resource (a queue needs a namespace, for example), add a check in `Assert-InfraSpecSemantics` in `Private/Spec.ps1`.
5. Add it to the example spec, regenerate the example output, and run `tests/Test-Generator.ps1`.
