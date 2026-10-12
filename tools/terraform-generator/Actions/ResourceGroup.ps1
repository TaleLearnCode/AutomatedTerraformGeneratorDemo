# resource_group -> azurerm_resource_group (IG-002, IG-003, IG-004)
function New-ResourceGroupHcl {
    param($Context, $Resource)
    $body = @(
        (New-HclAttr 'name' ('local.names.' + (Get-NameId $Resource)))
        (New-HclAttr 'location' 'local.region')
        (New-HclAttr 'tags' 'local.tags')
    )
    Add-OutputDefinition $Context 'resource_group_name' ((Get-Address $Context 'resource_group') + '.name') 'Name of the environment resource group.'
    New-HclResource 'azurerm_resource_group' $Resource.Label $body
}
