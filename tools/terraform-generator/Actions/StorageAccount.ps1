# storage_account -> azurerm_storage_account plus one azurerm_storage_container per entry in `containers`
# (IG-006, IG-008: shared key access disabled, no public blob access, TLS 1.2).
function New-StorageAccountHcl {
    param($Context, $Resource)
    $body = @(Get-CommonAttributes $Context $Resource) + @(
        (New-HclAttr 'account_kind' '"StorageV2"')
        (New-HclAttr 'account_tier' '"Standard"')
        (New-HclAttr 'account_replication_type' (Get-FieldHcl $Context $Resource 'replication_type' 'LRS'))
        (New-HclAttr 'access_tier' (Get-FieldHcl $Context $Resource 'access_tier' 'Hot'))
        (New-HclAttr 'min_tls_version' '"TLS1_2"')
        (New-HclAttr 'shared_access_key_enabled' 'false')
        (New-HclAttr 'allow_nested_items_to_be_public' 'false')
        (New-HclAttr 'tags' 'local.tags')
    )
    $blocks = @(New-HclResource 'azurerm_storage_account' $Resource.Label $body)

    $account = Get-Address $Context 'storage_account' $null
    foreach ($container in @($Resource.Data['containers'])) {
        $containerBody = @(
            (New-HclAttr 'name' (ConvertTo-HclValue $container))
            (New-HclAttr 'storage_account_id' "$account.id")
            (New-HclAttr 'container_access_type' '"private"')
        )
        $blocks += (New-HclResource 'azurerm_storage_container' (ConvertTo-Label $container) $containerBody)
    }
    return $blocks
}
