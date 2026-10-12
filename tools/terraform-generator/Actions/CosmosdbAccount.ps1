# cosmosdb_account -> azurerm_cosmosdb_account (IG-008, IG-022)
# NoSQL API, serverless, single region, continuous backup, local (key) authentication disabled.
function New-CosmosdbAccountHcl {
    param($Context, $Resource)
    $days = Get-FieldHcl $Context $Resource 'backup_retention_days'
    $tier = if ($days -match '^\d+$') { if ([int]$days -eq 30) { '"Continuous30Days"' } else { '"Continuous7Days"' } }
            else { "$days == 30 ? `"Continuous30Days`" : `"Continuous7Days`"" }

    $body = @(Get-CommonAttributes $Context $Resource) + @(
        (New-HclAttr 'offer_type' '"Standard"')
        (New-HclAttr 'kind' '"GlobalDocumentDB"')
        (New-HclAttr 'local_authentication_enabled' 'false')
        (New-HclAttr 'tags' 'local.tags')
        (New-HclBlock 'capabilities' @((New-HclAttr 'name' '"EnableServerless"')))
        (New-HclBlock 'consistency_policy' @((New-HclAttr 'consistency_level' (Get-FieldHcl $Context $Resource 'consistency_level'))))
        (New-HclBlock 'geo_location' @(
                (New-HclAttr 'location' 'local.region')
                (New-HclAttr 'failover_priority' '0')
                (New-HclAttr 'zone_redundant' 'false')
            ))
        (New-HclBlock 'backup' @(
                (New-HclAttr 'type' '"Continuous"')
                (New-HclAttr 'tier' $tier)
            ))
    )
    Add-OutputDefinition $Context 'cosmosdb_endpoint' ((Get-Address $Context 'cosmosdb_account') + '.endpoint') 'Cosmos DB account endpoint.'
    New-HclResource 'azurerm_cosmosdb_account' $Resource.Label $body
}
