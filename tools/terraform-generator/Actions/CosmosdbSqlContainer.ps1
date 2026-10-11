# cosmosdb_sql_container -> azurerm_cosmosdb_sql_container (IG-022)
function New-CosmosdbSqlContainerHcl {
    param($Context, $Resource)
    $account = Get-SingletonAddress $Context 'cosmosdb_account'
    $database = Get-Address $Context 'cosmosdb_sql_database' $Resource.Data['database']
    $body = @(
        (New-HclAttr 'name' ('local.names.' + (Get-NameId $Resource)))
        (New-HclAttr 'resource_group_name' ((Get-SingletonAddress $Context 'resource_group') + '.name'))
        (New-HclAttr 'account_name' "$account.name")
        (New-HclAttr 'database_name' "$database.name")
        (New-HclAttr 'partition_key_paths' (ConvertTo-HclValue @($Resource.Data['partition_key_path'])))
    )
    $unique = @($Resource.Data['unique_key_paths'] | Where-Object { $_ })
    if ($unique.Count -gt 0) {
        $body += (New-HclBlock 'unique_key' @((New-HclAttr 'paths' (ConvertTo-HclValue $unique))))
    }
    New-HclResource 'azurerm_cosmosdb_sql_container' $Resource.Label $body
}
