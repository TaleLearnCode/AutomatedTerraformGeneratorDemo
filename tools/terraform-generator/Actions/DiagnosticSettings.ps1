# diagnostics: true -> azurerm_monitor_diagnostic_setting (IG-012)
# Sends all log categories and all metrics to the Log Analytics workspace.
function New-DiagnosticSettingHcl {
    param($Context, $Resource)
    $workspace = Get-SingletonAddress $Context 'log_analytics_workspace'
    $target = Get-Address $Context $Resource.Type $Resource.Key
    $body = @(
        (New-HclAttr 'name' '"send-to-log-analytics"')
        (New-HclAttr 'target_resource_id' "$target.id")
        (New-HclAttr 'log_analytics_workspace_id' "$workspace.id")
        (New-HclBlock 'enabled_log' @((New-HclAttr 'category_group' '"allLogs"')))
        (New-HclBlock 'enabled_metric' @((New-HclAttr 'category' '"AllMetrics"')))
    )
    New-HclResource 'azurerm_monitor_diagnostic_setting' ('{0}_{1}' -f $Resource.Type, $Resource.Label).Replace('_main', '') $body
}
