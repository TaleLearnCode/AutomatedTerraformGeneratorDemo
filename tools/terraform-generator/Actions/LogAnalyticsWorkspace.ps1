# log_analytics_workspace -> azurerm_log_analytics_workspace (IG-011, IG-012; retention varies, section 7)
function New-LogAnalyticsWorkspaceHcl {
    param($Context, $Resource)
    $body = @(Get-CommonAttributes $Context $Resource) + @(
        (New-HclAttr 'sku' '"PerGB2018"')
        (New-HclAttr 'retention_in_days' (Get-FieldHcl $Context $Resource 'retention_in_days'))
        (New-HclAttr 'tags' 'local.tags')
    )
    New-HclResource 'azurerm_log_analytics_workspace' $Resource.Label $body
}
