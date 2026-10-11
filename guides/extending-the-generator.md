# Extending the Generator

The generator has one script per resource type, so adding a type means adding a small script and registering it in three places. This guide walks through a complete example: adding a Service Bus **queue** (`servicebus_queue`). Work from the root of the repository, inside `tools/terraform-generator`.

## How a resource type is wired

| Piece | Where | Job |
|---|---|---|
| Type table | `Private/ResourceTypes.ps1` | Lists the type, its Terraform resource, its name abbreviation and whether it needs a `key`. |
| Action script | `Actions/<PascalCaseType>.ps1` | Defines `New-<PascalCaseType>Hcl`, which returns the Terraform for one resource. |
| Schema | `schema/infra-spec.schema.json` | Defines the fields the spec may use for that type. |
| Dependency check | `Private/Spec.ps1`, `Assert-InfraSpecSemantics` | Optional. Reports a clear error when the resource needs another resource that is not in the spec. |

The orchestrator finds an action by name: the type `servicebus_queue` becomes the function `New-ServicebusQueueHcl` in `Actions/ServicebusQueue.ps1`. The test script checks that the schema, the table and the action scripts agree.

## 1. Register the type

In `Private/ResourceTypes.ps1`, add a row to `$script:ResourceTypes`. The order of the rows is the order resources appear in `main.tf`, so put it after the namespace it depends on.

```powershell
servicebus_queue = @{ Terraform = 'azurerm_servicebus_queue'; Abbreviation = ''; Keyed = $true; Component = $false }
```

- `Abbreviation` is the prefix in the name pattern. Queues, like topics and subscriptions, have fixed names, so it is empty and the name is the spec `key`.
- `Keyed` is `$true` when a spec can contain more than one of the type, so each needs a `key`.
- `Component` is `$true` only when the key is also part of the Azure name, as with container apps (`ca-...-api-...`).

## 2. Write the action script

Create `Actions/ServicebusQueue.ps1`:

```powershell
# servicebus_queue -> azurerm_servicebus_queue
function New-ServicebusQueueHcl {
    param($Context, $Resource)
    $namespace = Get-SingletonAddress $Context 'servicebus_namespace'
    $body = @(
        (New-HclAttr 'name' ('local.names.' + (Get-NameId $Resource)))
        (New-HclAttr 'namespace_id' "$namespace.id")
        (New-HclAttr 'max_delivery_count' (Get-FieldHcl $Context $Resource 'max_delivery_count'))
        (New-HclAttr 'default_message_ttl' (Get-FieldHcl $Context $Resource 'default_message_ttl'))
        (New-HclAttr 'dead_lettering_on_message_expiration' (Get-FieldHcl $Context $Resource 'dead_letter_on_expiration' $true))
    )
    New-HclResource 'azurerm_servicebus_queue' $Resource.Label $body
}
```

The helpers you will use most:

| Helper | Use |
|---|---|
| `New-HclAttr name value` | One `name = value` line. The value is HCL text. |
| `New-HclBlock name items` | A nested block such as `identity { ... }`. |
| `New-HclMap name entries` | A map attribute such as `app_settings`. |
| `New-HclResource type label body` | The whole resource. |
| `Get-FieldHcl $Context $Resource 'field' [default]` | A spec field as HCL. A required field with no default fails clearly if the spec leaves it out. A per-environment value becomes a Terraform variable. |
| `Get-Address $Context type key` and `Get-SingletonAddress $Context type` | The Terraform address of another resource, for references. |
| `Get-NameId $Resource` | The key into `local.names` for this resource's name. |
| `Get-CommonAttributes $Context $Resource` | `name`, `location` and `resource_group_name`, for resources that take all three. |
| `Add-OutputDefinition` | Add an output to `outputs.tf`. |

Security defaults that the architecture requires belong in the action script, not in the spec. That is what makes them identical every time.

Return one string per Terraform block. A script that produces more than one block, such as a resource plus a rule, returns an array of strings.

## 3. Add the schema entry

In `schema/infra-spec.schema.json`, add `"servicebus_queue"` to the `enum` under `resources.items.properties.type`, and add a conditional entry to the `allOf` list beside the others:

```json
{
  "if": { "properties": { "type": { "const": "servicebus_queue" } }, "required": ["type"] },
  "then": {
    "properties": {
      "type": { "const": "servicebus_queue" },
      "key": { "type": "string", "pattern": "^[a-z0-9][a-z0-9-]*$" },
      "max_delivery_count": { "type": "integer", "minimum": 1 },
      "default_message_ttl": { "type": "string", "pattern": "^P(T?[0-9]+[DHMS])+$" },
      "dead_letter_on_expiration": { "type": "boolean" }
    },
    "required": ["type", "key", "max_delivery_count", "default_message_ttl"],
    "additionalProperties": false
  }
}
```

`additionalProperties: false` is what makes a misspelled field fail with a clear message instead of being ignored.

## 4. Add a dependency check

A queue needs a namespace. In `Private/Spec.ps1`, inside the `switch ($type)` in `Assert-InfraSpecSemantics`, add:

```powershell
'servicebus_queue' { if (-not (Test-Exists 'servicebus_namespace' $null)) { $errors.Add("${id}: needs a servicebus_namespace.") } }
```

Without it, a spec with no namespace would fail later with a less helpful error.

## 5. Try it

Add a queue to a copy of a spec:

```yaml
  - type: servicebus_queue
    key: work-item-retries
    max_delivery_count: 5
    default_message_ttl: P1D
```

Run the generator on that spec. In `main.tf` you should find:

```hcl
resource "azurerm_servicebus_queue" "work_item_retries" {
  name                                 = local.names.servicebus_queue_work_item_retries
  namespace_id                         = azurerm_servicebus_namespace.main.id
  max_delivery_count                   = 5
  default_message_ttl                  = "P1D"
  dead_lettering_on_message_expiration = true
}
```

Then run `terraform fmt -check` on the output, and run `terraform init` and `terraform validate` against the real provider. Confirm the arguments against the provider version you use, since the generator cannot check that for you.

## 6. Run the checks and document it

Run the generator's tests:

```powershell
.\tests\Test-Generator.ps1
```

They confirm that every type in the table is in the schema, that each has an action script, that output is identical across runs, and that bad specs are rejected. Update `docs/infra-spec-reference.md` with a row for the new type.

## Other kinds of change

- **Per-environment values.** To let a field differ between environments, add it to `$script:TunableFields` in `Private/ResourceTypes.ps1` and allow the `{ dev: .., qa: .., prd: .. }` form for it in the schema with a `oneOf`, as the existing tunable fields do.
- **Values read from another resource.** To let `settings:` reference an attribute, add it to `$script:ExposedAttributes`.
- **A new role.** Add it to `$script:Roles` and to the role list in the schema.
- **Different naming.** Change `Get-NameHcl` in `Private/Spec.ps1`.
- **Different security defaults.** Change the relevant action script.
