# container_app -> azurerm_container_app (IG-005, IG-009, IG-013, IG-020)
# HTTPS-only external ingress, single active revision, system-assigned identity, HTTP scale rule.
# The image is ignored after creation because the delivery pipeline replaces it (section 6.1).
function New-ContainerAppHcl {
    param($Context, $Resource)
    $environment = Get-SingletonAddress $Context 'container_app_environment'

    $envBlocks = foreach ($setting in (Get-SettingsSorted $Resource)) {
        New-HclBlock 'env' @(
            (New-HclAttr 'name' (ConvertTo-HclValue $setting['name']))
            (New-HclAttr 'value' (Resolve-SettingHcl $Context $setting))
        )
    }

    $container = New-HclBlock 'container' (@(
            (New-HclAttr 'name' (ConvertTo-HclValue $Resource.Key))
            (New-HclAttr 'image' (ConvertTo-HclValue $Resource.Data['image']))
            (New-HclAttr 'cpu' (Get-FieldHcl $Context $Resource 'cpu'))
            (New-HclAttr 'memory' (Get-FieldHcl $Context $Resource 'memory'))
        ) + @($envBlocks | Where-Object { $null -ne $_ }))

    $template = New-HclBlock 'template' @(
        (New-HclAttr 'min_replicas' (Get-FieldHcl $Context $Resource 'min_replicas'))
        (New-HclAttr 'max_replicas' (Get-FieldHcl $Context $Resource 'max_replicas'))
        $container
        (New-HclBlock 'http_scale_rule' @(
                (New-HclAttr 'name' '"http-concurrency"')
                (New-HclAttr 'concurrent_requests' (ConvertTo-HclString ([string]$Resource.Data['http_concurrency'])))
            ))
    )

    $body = @(
        (New-HclAttr 'name' ('local.names.' + (Get-NameId $Resource)))
        (New-HclAttr 'resource_group_name' ((Get-SingletonAddress $Context 'resource_group') + '.name'))
        (New-HclAttr 'container_app_environment_id' "$environment.id")
        (New-HclAttr 'workload_profile_name' '"Consumption"')
        (New-HclAttr 'revision_mode' '"Single"')
        (New-HclAttr 'tags' 'local.tags')
        (New-HclBlock 'identity' @((New-HclAttr 'type' '"SystemAssigned"')))
        (New-HclBlock 'ingress' @(
                (New-HclAttr 'external_enabled' 'true')
                (New-HclAttr 'target_port' (Get-FieldHcl $Context $Resource 'target_port'))
                (New-HclAttr 'allow_insecure_connections' 'false')
                (New-HclBlock 'traffic_weight' @(
                        (New-HclAttr 'latest_revision' 'true')
                        (New-HclAttr 'percentage' '100')
                    ))
            ))
        $template
        (New-HclBlock 'lifecycle' @((New-HclAttr 'ignore_changes' '[template[0].container[0].image]')))
    )

    $address = Get-Address $Context 'container_app' $Resource.Key
    Add-OutputDefinition $Context ('container_app_{0}_url' -f $Resource.Label) ('"https://${' + $address + '.ingress[0].fqdn}"') "Public HTTPS URL of container app '$($Resource.Key)'."
    New-HclResource 'azurerm_container_app' $Resource.Label $body
}
