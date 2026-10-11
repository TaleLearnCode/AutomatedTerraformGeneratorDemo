# access: -> azurerm_role_assignment / azurerm_cosmosdb_sql_role_assignment (IG-009, section 6.3)
# One block per grant in the spec's `access:` list, in the order given.
function New-RoleAssignmentHcl {
    param($Context, $Grant)

    $principalType, $principalKey = $Grant['principal'].Split('/', 2)
    $scopeType, $scopeKey = $Grant['scope'].Split('/', 2)
    $role = $script:Roles[$Grant['role']]
    $principal = Get-Address $Context $principalType $principalKey
    $scope = Get-Address $Context $scopeType $scopeKey

    $roleSlug = ($Grant['role'].ToLowerInvariant() -replace '[^a-z0-9]+', '_').Trim('_')
    $scopePart = if ($scopeKey) { ConvertTo-Label $scopeKey } else { $scopeType }
    $label = '{0}_{1}_{2}' -f (ConvertTo-Label $principalKey), $roleSlug, $scopePart

    if ($role.Kind -eq 'cosmos') {
        $account = Get-SingletonAddress $Context 'cosmosdb_account'
        $database = $Context.Index["$scopeType/$scopeKey"]
        $body = @(
            (New-HclAttr 'resource_group_name' ((Get-SingletonAddress $Context 'resource_group') + '.name'))
            (New-HclAttr 'account_name' "$account.name")
            (New-HclAttr 'role_definition_id' ('"${' + $account + '.id}/sqlRoleDefinitions/' + $role.RoleDefinitionId + '"'))
            (New-HclAttr 'principal_id' "$principal.identity[0].principal_id")
            (New-HclAttr 'scope' ('"${' + $account + '.id}/dbs/${' + $scope + '.name}"'))
        )
        return New-HclResource 'azurerm_cosmosdb_sql_role_assignment' $label $body
    }

    $body = @(
        (New-HclAttr 'scope' "$scope.id")
        (New-HclAttr 'role_definition_name' (ConvertTo-HclValue $Grant['role']))
        (New-HclAttr 'principal_id' "$principal.identity[0].principal_id")
    )
    New-HclResource 'azurerm_role_assignment' $label $body
}
