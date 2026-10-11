# app_configuration -> azurerm_app_configuration (IG-008: local authentication disabled; SKU varies, section 7)
function New-AppConfigurationHcl {
    param($Context, $Resource)
    $body = @(Get-CommonAttributes $Context $Resource) + @(
        (New-HclAttr 'sku' (Get-FieldHcl $Context $Resource 'sku'))
        (New-HclAttr 'local_auth_enabled' 'false')
        (New-HclAttr 'tags' 'local.tags')
    )
    Add-OutputDefinition $Context 'app_configuration_endpoint' ((Get-Address $Context 'app_configuration') + '.endpoint') 'App Configuration endpoint.'
    New-HclResource 'azurerm_app_configuration' $Resource.Label $body
}
