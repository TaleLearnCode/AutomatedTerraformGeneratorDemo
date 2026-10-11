# servicebus_subscription -> azurerm_servicebus_subscription, plus azurerm_servicebus_subscription_rule
# when the spec gives a SQL filter (IG-007). A subscription without a filter receives every message.
function New-ServicebusSubscriptionHcl {
    param($Context, $Resource)
    $topic = Get-Address $Context 'servicebus_topic' $Resource.Data['topic']
    $body = @(
        (New-HclAttr 'name' ('local.names.' + (Get-NameId $Resource)))
        (New-HclAttr 'topic_id' "$topic.id")
        (New-HclAttr 'max_delivery_count' (Get-FieldHcl $Context $Resource 'max_delivery_count'))
        (New-HclAttr 'lock_duration' (Get-FieldHcl $Context $Resource 'lock_duration'))
        (New-HclAttr 'default_message_ttl' (Get-FieldHcl $Context $Resource 'default_message_ttl'))
        (New-HclAttr 'dead_lettering_on_message_expiration' (Get-FieldHcl $Context $Resource 'dead_letter_on_expiration'))
    )
    $blocks = @(New-HclResource 'azurerm_servicebus_subscription' $Resource.Label $body)

    $filter = $Resource.Data['filter']
    if ($filter) {
        $ruleBody = @(
            (New-HclAttr 'name' (ConvertTo-HclValue $filter['name']))
            (New-HclAttr 'subscription_id' ((Get-Address $Context 'servicebus_subscription' $Resource.Key) + '.id'))
            (New-HclAttr 'filter_type' '"SqlFilter"')
            (New-HclAttr 'sql_filter' (ConvertTo-HclValue $filter['sql']))
        )
        $blocks += (New-HclResource 'azurerm_servicebus_subscription_rule' $Resource.Label $ruleBody)
    }
    return $blocks
}
