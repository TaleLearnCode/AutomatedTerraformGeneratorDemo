# ResourceTypes.ps1
# The single place that knows every resource `type` the YAML spec can contain.
#
#   Terraform     the azurerm resource the type becomes
#   Abbreviation  the prefix used when naming the Azure resource (Infrastructure Guide, section 6.7)
#   Keyed         true when a spec entry needs a `key` (more than one can exist, or it has a fixed name)
#   Component     true when the key is also part of the Azure resource name (e.g. ca-...-api-...)

$script:ResourceTypes = [ordered]@{
    resource_group          = @{ Terraform = 'azurerm_resource_group';                  Abbreviation = 'rg';     Keyed = $false; Component = $false }
    log_analytics_workspace = @{ Terraform = 'azurerm_log_analytics_workspace';         Abbreviation = 'log';    Keyed = $false; Component = $false }
    application_insights    = @{ Terraform = 'azurerm_application_insights';            Abbreviation = 'appi';   Keyed = $false; Component = $false }
    app_configuration       = @{ Terraform = 'azurerm_app_configuration';               Abbreviation = 'appcs';  Keyed = $false; Component = $false }
    key_vault               = @{ Terraform = 'azurerm_key_vault';                       Abbreviation = 'kv';     Keyed = $false; Component = $false }
    servicebus_namespace    = @{ Terraform = 'azurerm_servicebus_namespace';            Abbreviation = 'sbns';   Keyed = $false; Component = $false }
    servicebus_topic        = @{ Terraform = 'azurerm_servicebus_topic';                Abbreviation = '';       Keyed = $true;  Component = $false }
    servicebus_subscription = @{ Terraform = 'azurerm_servicebus_subscription';         Abbreviation = '';       Keyed = $true;  Component = $false }
    storage_account         = @{ Terraform = 'azurerm_storage_account';                 Abbreviation = 'st';     Keyed = $false; Component = $false }
    cosmosdb_account        = @{ Terraform = 'azurerm_cosmosdb_account';                Abbreviation = 'cosmos'; Keyed = $false; Component = $false }
    cosmosdb_sql_database   = @{ Terraform = 'azurerm_cosmosdb_sql_database';           Abbreviation = '';       Keyed = $true;  Component = $false }
    cosmosdb_sql_container  = @{ Terraform = 'azurerm_cosmosdb_sql_container';          Abbreviation = '';       Keyed = $true;  Component = $false }
    container_app_environment = @{ Terraform = 'azurerm_container_app_environment';     Abbreviation = 'cae';    Keyed = $false; Component = $false }
    container_app           = @{ Terraform = 'azurerm_container_app';                   Abbreviation = 'ca';     Keyed = $true;  Component = $true }
    function_app            = @{ Terraform = 'azurerm_function_app_flex_consumption';   Abbreviation = 'func';   Keyed = $true;  Component = $true }
}

# Attributes one resource can expose to another's settings (`from:` / `attribute:` in the spec).
# @ADDR@ is replaced with the Terraform address of the referenced resource.
$script:ExposedAttributes = @{
    app_configuration    = @{ endpoint = '@ADDR@.endpoint' }
    key_vault            = @{ uri = '@ADDR@.vault_uri' }
    application_insights = @{ connection_string = '@ADDR@.connection_string' }
    cosmosdb_account     = @{ endpoint = '@ADDR@.endpoint' }
    servicebus_namespace = @{ fully_qualified_namespace = '"${@ADDR@.name}.servicebus.windows.net"' }
    storage_account      = @{ name = '@ADDR@.name' }
}

# Fields that may differ per environment (`perEnvironment:` in the spec). Anything else is a
# structural decision and must be the same everywhere (Infrastructure Guide, section 7).
$script:TunableFields = @{
    log_analytics_workspace = @{ retention_in_days = 'number' }
    app_configuration       = @{ sku = 'string' }
    key_vault               = @{ purge_protection = 'bool' }
    cosmosdb_account        = @{ backup_retention_days = 'number' }
    container_app           = @{ min_replicas = 'number'; max_replicas = 'number' }
    function_app            = @{ max_instance_count = 'number' }
}

# Roles the spec's `access:` list may grant (Infrastructure Guide, section 6.3), and what each can be scoped to.
#   Kind 'rbac'   -> azurerm_role_assignment (Azure control-plane RBAC)
#   Kind 'cosmos' -> azurerm_cosmosdb_sql_role_assignment (Cosmos DB data-plane RBAC)
$script:Roles = [ordered]@{
    'Azure Service Bus Data Receiver'     = @{ Kind = 'rbac';   ScopeTypes = @('servicebus_topic', 'servicebus_namespace') }
    'Azure Service Bus Data Sender'       = @{ Kind = 'rbac';   ScopeTypes = @('servicebus_topic', 'servicebus_namespace') }
    'App Configuration Data Reader'       = @{ Kind = 'rbac';   ScopeTypes = @('app_configuration') }
    'Key Vault Secrets User'              = @{ Kind = 'rbac';   ScopeTypes = @('key_vault') }
    'Storage Blob Data Owner'             = @{ Kind = 'rbac';   ScopeTypes = @('storage_account') }
    'Cosmos DB Built-in Data Contributor' = @{ Kind = 'cosmos'; ScopeTypes = @('cosmosdb_sql_database'); RoleDefinitionId = '00000000-0000-0000-0000-000000000002' }
}

# Workloads that receive a system-assigned managed identity and can be the `principal` of an access entry.
$script:PrincipalTypes = @('container_app', 'function_app')

# Resources that can send diagnostics to Log Analytics (`diagnostics: true` in the spec).
$script:DiagnosticTypes = @('key_vault', 'servicebus_namespace', 'cosmosdb_account')
