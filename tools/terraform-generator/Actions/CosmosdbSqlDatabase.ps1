# cosmosdb_sql_database -> azurerm_cosmosdb_sql_database (IG-022: no throughput, the account is serverless)
function New-CosmosdbSqlDatabaseHcl {
    param($Context, $Resource)
    $account = Get-SingletonAddress $Context 'cosmosdb_account'
    $body = @(
        (New-HclAttr 'name' ('local.names.' + (Get-NameId $Resource)))
        (New-HclAttr 'resource_group_name' ((Get-SingletonAddress $Context 'resource_group') + '.name'))
        (New-HclAttr 'account_name' "$account.name")
    )
    New-HclResource 'azurerm_cosmosdb_sql_database' $Resource.Label $body
}
