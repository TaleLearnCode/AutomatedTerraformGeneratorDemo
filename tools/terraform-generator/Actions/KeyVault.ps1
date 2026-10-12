# key_vault -> azurerm_key_vault (IG-010: RBAC authorization, 90-day soft delete, purge protection varies)
function New-KeyVaultHcl {
    param($Context, $Resource)
    $body = @(Get-CommonAttributes $Context $Resource) + @(
        (New-HclAttr 'tenant_id' 'data.azurerm_client_config.current.tenant_id')
        (New-HclAttr 'sku_name' '"standard"')
        (New-HclAttr 'rbac_authorization_enabled' 'true')
        (New-HclAttr 'soft_delete_retention_days' (Get-FieldHcl $Context $Resource 'soft_delete_retention_days' 90))
        (New-HclAttr 'purge_protection_enabled' (Get-FieldHcl $Context $Resource 'purge_protection'))
        (New-HclAttr 'tags' 'local.tags')
    )
    Add-OutputDefinition $Context 'key_vault_uri' ((Get-Address $Context 'key_vault') + '.vault_uri') 'Key Vault URI.'
    New-HclResource 'azurerm_key_vault' $Resource.Label $body
}
