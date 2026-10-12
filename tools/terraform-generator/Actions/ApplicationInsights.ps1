# application_insights -> azurerm_application_insights, workspace-based (IG-011)
function New-ApplicationInsightsHcl {
    param($Context, $Resource)
    $workspace = Get-SingletonAddress $Context 'log_analytics_workspace'
    $body = @(Get-CommonAttributes $Context $Resource) + @(
        (New-HclAttr 'application_type' '"web"')
        (New-HclAttr 'workspace_id' "$workspace.id")
        (New-HclAttr 'tags' 'local.tags')
    )
    Add-OutputDefinition $Context 'application_insights_connection_string' ((Get-Address $Context 'application_insights') + '.connection_string') 'Application Insights connection string.' -Sensitive
    New-HclResource 'azurerm_application_insights' $Resource.Label $body
}
