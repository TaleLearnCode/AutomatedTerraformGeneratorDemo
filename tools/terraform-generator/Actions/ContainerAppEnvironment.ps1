# container_app_environment -> azurerm_container_app_environment (IG-011: logs go to the workspace;
# section 6.1: Consumption workload profile only)
function New-ContainerAppEnvironmentHcl {
    param($Context, $Resource)
    $workspace = Get-SingletonAddress $Context 'log_analytics_workspace'
    $body = @(Get-CommonAttributes $Context $Resource) + @(
        (New-HclAttr 'log_analytics_workspace_id' "$workspace.id")
        (New-HclAttr 'tags' 'local.tags')
        (New-HclBlock 'workload_profile' @(
                (New-HclAttr 'name' '"Consumption"')
                (New-HclAttr 'workload_profile_type' '"Consumption"')
            ))
    )
    New-HclResource 'azurerm_container_app_environment' $Resource.Label $body
}
