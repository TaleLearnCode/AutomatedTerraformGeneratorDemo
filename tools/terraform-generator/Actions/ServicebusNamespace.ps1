# servicebus_namespace -> azurerm_servicebus_namespace (IG-007, IG-008: local authentication disabled)
function New-ServicebusNamespaceHcl {
    param($Context, $Resource)
    $body = @(Get-CommonAttributes $Context $Resource) + @(
        (New-HclAttr 'sku' (Get-FieldHcl $Context $Resource 'sku' 'Standard'))
        (New-HclAttr 'minimum_tls_version' (Get-FieldHcl $Context $Resource 'minimum_tls_version' '1.2'))
        (New-HclAttr 'local_auth_enabled' 'false')
        (New-HclAttr 'tags' 'local.tags')
    )
    Add-OutputDefinition $Context 'servicebus_namespace_name' ((Get-Address $Context 'servicebus_namespace') + '.name') 'Service Bus namespace name.'
    New-HclResource 'azurerm_servicebus_namespace' $Resource.Label $body
}
