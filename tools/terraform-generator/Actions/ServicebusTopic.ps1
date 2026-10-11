# servicebus_topic -> azurerm_servicebus_topic (IG-007)
function New-ServicebusTopicHcl {
    param($Context, $Resource)
    $namespace = Get-SingletonAddress $Context 'servicebus_namespace'
    $body = @(
        (New-HclAttr 'name' ('local.names.' + (Get-NameId $Resource)))
        (New-HclAttr 'namespace_id' "$namespace.id")
        (New-HclAttr 'default_message_ttl' (Get-FieldHcl $Context $Resource 'default_message_ttl'))
    )
    $window = $Resource.Data['duplicate_detection_window']
    if ($window) {
        $body += (New-HclAttr 'requires_duplicate_detection' 'true')
        $body += (New-HclAttr 'duplicate_detection_history_time_window' (ConvertTo-HclValue $window))
    }
    New-HclResource 'azurerm_servicebus_topic' $Resource.Label $body
}
