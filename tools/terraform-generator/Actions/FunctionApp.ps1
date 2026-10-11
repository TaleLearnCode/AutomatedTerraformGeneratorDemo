# function_app -> azurerm_service_plan (FC1) + azurerm_function_app_flex_consumption (IG-006, IG-009, IG-015)
# Linux, system-assigned identity, deployment package in the host storage account read through the identity.
function New-FunctionAppHcl {
    param($Context, $Resource)
    $storage = Get-SingletonAddress $Context 'storage_account'
    $container = 'azurerm_storage_container.' + (ConvertTo-Label $Resource.Data['deployment_container'])
    $group = (Get-SingletonAddress $Context 'resource_group') + '.name'
    $planAddress = 'azurerm_service_plan.' + $Resource.Label

    $plan = New-HclResource 'azurerm_service_plan' $Resource.Label @(
        (New-HclAttr 'name' ('local.names.' + (Get-NameId $Resource) + '_plan'))
        (New-HclAttr 'location' 'local.region')
        (New-HclAttr 'resource_group_name' $group)
        (New-HclAttr 'os_type' '"Linux"')
        (New-HclAttr 'sku_name' '"FC1"')
        (New-HclAttr 'tags' 'local.tags')
    )

    $settings = [ordered]@{}
    foreach ($setting in (Get-SettingsSorted $Resource)) { $settings[$setting['name']] = Resolve-SettingHcl $Context $setting }

    $body = @(
        (New-HclAttr 'name' ('local.names.' + (Get-NameId $Resource)))
        (New-HclAttr 'location' 'local.region')
        (New-HclAttr 'resource_group_name' $group)
        (New-HclAttr 'service_plan_id' "$planAddress.id")
        (New-HclAttr 'storage_container_type' '"blobContainer"')
        (New-HclAttr 'storage_container_endpoint' ('"${' + $storage + '.primary_blob_endpoint}${' + $container + '.name}"'))
        (New-HclAttr 'storage_authentication_type' '"SystemAssignedIdentity"')
        (New-HclAttr 'runtime_name' (Get-FieldHcl $Context $Resource 'runtime'))
        (New-HclAttr 'runtime_version' (Get-FieldHcl $Context $Resource 'runtime_version'))
        (New-HclAttr 'maximum_instance_count' (Get-FieldHcl $Context $Resource 'max_instance_count'))
        (New-HclAttr 'instance_memory_in_mb' (Get-FieldHcl $Context $Resource 'instance_memory_mb'))
        (New-HclAttr 'tags' 'local.tags')
        (New-HclMap 'app_settings' $settings)
        (New-HclBlock 'identity' @((New-HclAttr 'type' '"SystemAssigned"')))
        (New-HclBlock 'site_config' @())
    )

    Add-OutputDefinition $Context ('function_app_{0}_name' -f $Resource.Label) ((Get-Address $Context 'function_app' $Resource.Key) + '.name') "Name of function app '$($Resource.Key)'."
    return @($plan, (New-HclResource 'azurerm_function_app_flex_consumption' $Resource.Label $body))
}
