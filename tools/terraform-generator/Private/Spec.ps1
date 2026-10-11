# Spec.ps1
# Reads the YAML spec, validates it, and builds the context that every action script receives.

function Read-InfraSpec {
    <# Returns the parsed spec plus a SHA-256 of its text (line endings normalised) for traceability. #>
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue)) {
        if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
            throw 'The powershell-yaml module is required. Install it with: Install-Module powershell-yaml -Scope CurrentUser'
        }
        Import-Module powershell-yaml -ErrorAction Stop
    }
    $text = (Get-Content -LiteralPath $Path -Raw).Replace("`r`n", "`n")
    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($text)
    $hash = [System.BitConverter]::ToString([System.Security.Cryptography.SHA256]::HashData($bytes)).Replace('-', '').ToLowerInvariant()
    return [pscustomobject]@{ Spec = (ConvertFrom-Yaml $text); Sha256 = $hash }
}

function Assert-InfraSpecSchema {
    <# Structural validation (field names, types, allowed values) against the JSON Schema. #>
    param([Parameter(Mandatory)]$Spec, [Parameter(Mandatory)][string]$SchemaPath)

    $json = $Spec | ConvertTo-Json -Depth 20
    $schemaErrors = $null
    $valid = Test-Json -Json $json -SchemaFile $SchemaPath -ErrorAction SilentlyContinue -ErrorVariable schemaErrors
    if (-not $valid) {
        $messages = @($schemaErrors | ForEach-Object { '  - ' + $_.Exception.Message })
        throw ("The spec does not match the schema:`n" + ($messages -join "`n"))
    }
}

function Test-IsEnvironmentMap { param($Value) return ($Value -is [System.Collections.IDictionary]) }

function Assert-InfraSpecSemantics {
    <# Cross-field rules the schema cannot express: references resolve, singletons are single, per-environment maps are complete. #>
    param([Parameter(Mandatory)]$Spec)

    $errors = [System.Collections.Generic.List[string]]::new()
    $environments = @($Spec['environments'])
    $entries = @($Spec['resources'])

    if (@($environments | Select-Object -Unique).Count -ne $environments.Count) { $errors.Add('environments contains duplicates.') }
    if ($Spec['tags'].Contains('environment')) { $errors.Add("tags must not define 'environment'; the generator adds it from var.environment.") }

    $seen = @{}
    foreach ($entry in $entries) {
        $type = $entry['type']
        $meta = $script:ResourceTypes[$type]
        $key = $entry['key']
        $id = if ($key) { "$type/$key" } else { $type }
        if ($meta.Keyed -and -not $key) { $errors.Add("$type requires a key."); continue }
        if (-not $meta.Keyed -and $key) { $errors.Add("$type does not take a key (found '$key')."); continue }
        if ($seen.ContainsKey($id)) { $errors.Add("Duplicate resource $id.") }
        $seen[$id] = $true

        # The schema already limits per-environment maps to the tunable fields; here we check they are complete.
        $tunable = $script:TunableFields[$type]
        if ($tunable) {
            foreach ($field in $tunable.Keys) {
                if (-not (Test-IsEnvironmentMap $entry[$field])) { continue }
                $given = @($entry[$field].Keys | Sort-Object)
                $wanted = @($environments | Sort-Object)
                if (($given -join ',') -ne ($wanted -join ',')) { $errors.Add("${id}: '$field' must list exactly these environments: $($environments -join ', ').") }
            }
        }
    }

    function Test-Exists($Type, $Key) { return $seen.ContainsKey($(if ($Key) { "$Type/$Key" } else { $Type })) }

    if (-not (Test-Exists 'resource_group' $null)) { $errors.Add('A resource_group is required.') }
    foreach ($entry in $entries) {
        $type = $entry['type']; $key = $entry['key']; $id = if ($key) { "$type/$key" } else { $type }
        if ($type -ne 'resource_group' -and -not (Test-Exists 'resource_group' $null)) { break }
        switch ($type) {
            'application_insights' { if (-not (Test-Exists 'log_analytics_workspace' $null)) { $errors.Add("${id}: needs a log_analytics_workspace.") } }
            'servicebus_topic' { if (-not (Test-Exists 'servicebus_namespace' $null)) { $errors.Add("${id}: needs a servicebus_namespace.") } }
            'servicebus_subscription' { if (-not (Test-Exists 'servicebus_topic' $entry['topic'])) { $errors.Add("${id}: topic '$($entry['topic'])' is not defined.") } }
            'cosmosdb_sql_database' { if (-not (Test-Exists 'cosmosdb_account' $null)) { $errors.Add("${id}: needs a cosmosdb_account.") } }
            'cosmosdb_sql_container' { if (-not (Test-Exists 'cosmosdb_sql_database' $entry['database'])) { $errors.Add("${id}: database '$($entry['database'])' is not defined.") } }
            'container_app_environment' { if (-not (Test-Exists 'log_analytics_workspace' $null)) { $errors.Add("${id}: needs a log_analytics_workspace.") } }
            'container_app' { if (-not (Test-Exists 'container_app_environment' $null)) { $errors.Add("${id}: needs a container_app_environment.") } }
            'function_app' {
                if (-not (Test-Exists 'storage_account' $null)) { $errors.Add("${id}: needs a storage_account.") }
                else {
                    $storage = $entries | Where-Object { $_['type'] -eq 'storage_account' } | Select-Object -First 1
                    if (@($storage['containers']) -notcontains $entry['deployment_container']) { $errors.Add("${id}: deployment_container '$($entry['deployment_container'])' is not in the storage_account containers list.") }
                }
            }
        }
        if ($script:DiagnosticTypes -contains $type -and $entry['diagnostics'] -and -not (Test-Exists 'log_analytics_workspace' $null)) { $errors.Add("${id}: diagnostics needs a log_analytics_workspace.") }
        foreach ($setting in @($entry['settings'])) {
            if ($null -eq $setting -or -not $setting.Contains('from')) { continue }
            $sourceType, $attribute = $setting['from'].Split('.', 2)
            if (-not $script:ExposedAttributes.ContainsKey($sourceType) -or -not $script:ExposedAttributes[$sourceType].ContainsKey($attribute)) {
                $errors.Add("${id}: setting $($setting['name']) uses unknown source '$($setting['from'])'.")
            }
            elseif (-not (Test-Exists $sourceType $null)) { $errors.Add("${id}: setting $($setting['name']) reads from $sourceType, which is not defined.") }
        }
    }

    foreach ($grant in @($Spec['access'])) {
        if ($null -eq $grant) { continue }
        $principalType, $principalKey = $grant['principal'].Split('/', 2)
        $scopeType, $scopeKey = $grant['scope'].Split('/', 2)
        $label = "access $($grant['principal']) -> $($grant['role']) -> $($grant['scope'])"
        if ($script:PrincipalTypes -notcontains $principalType -or -not (Test-Exists $principalType $principalKey)) { $errors.Add("${label}: principal is not a defined container_app or function_app.") }
        if (-not (Test-Exists $scopeType $scopeKey)) { $errors.Add("${label}: scope is not defined.") }
        if ($script:Roles.Contains($grant['role']) -and $script:Roles[$grant['role']].ScopeTypes -notcontains $scopeType) { $errors.Add("${label}: this role cannot be scoped to $scopeType.") }
    }

    if ($errors.Count -gt 0) { throw ("The spec has problems:`n" + (($errors | ForEach-Object { "  - $_" }) -join "`n")) }
}

# --- Context --------------------------------------------------------------------------------------

function ConvertTo-Label {
    <# Terraform resource label from a spec key: lower case, anything but letters/digits becomes '_'. #>
    param([string]$Key)
    if (-not $Key) { return 'main' }
    return ($Key.ToLowerInvariant() -replace '[^a-z0-9]', '_')
}

function New-GenerationContext {
    param([Parameter(Mandatory)]$Spec, [Parameter(Mandatory)][string]$SpecFileName, [Parameter(Mandatory)][string]$SpecSha256)

    $resources = [System.Collections.Generic.List[object]]::new()
    $index = @{}
    foreach ($type in $script:ResourceTypes.Keys) {
        foreach ($entry in @($Spec['resources'] | Where-Object { $_['type'] -eq $type })) {
            $resource = [pscustomobject]@{ Type = $type; Key = $entry['key']; Label = (ConvertTo-Label $entry['key']); Data = $entry }
            $resources.Add($resource)
            $index["$type/$($entry['key'])"] = $resource
        }
    }
    return [pscustomobject]@{
        Spec         = $Spec
        SpecFileName = $SpecFileName
        SpecSha256   = $SpecSha256
        Environments = @($Spec['environments'])
        Resources    = $resources
        Index        = $index
        Variables    = [System.Collections.Generic.SortedDictionary[string, object]]::new([System.StringComparer]::Ordinal)
        Outputs      = [System.Collections.Generic.SortedDictionary[string, object]]::new([System.StringComparer]::Ordinal)
    }
}

function Get-Address {
    <# Terraform address (type.label) of a resource in the spec. #>
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$Type, [string]$Key)
    $resource = $Context.Index["$Type/$Key"]
    if ($null -eq $resource) { throw "No $Type resource with key '$Key' in the spec." }
    return '{0}.{1}' -f $script:ResourceTypes[$Type].Terraform, $resource.Label
}

function Get-SingletonAddress {
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$Type)
    return Get-Address -Context $Context -Type $Type -Key $null
}

function Get-NameId {
    <# Key used in local.names for a resource. #>
    param([Parameter(Mandatory)]$Resource)
    if ($Resource.Key) { return '{0}_{1}' -f $Resource.Type, $Resource.Label }
    return $Resource.Type
}

function Get-NameHcl {
    <# HCL expression for the Azure name of a resource (Infrastructure Guide, section 6.7). #>
    param([Parameter(Mandatory)]$Resource, [string]$Abbreviation)
    $meta = $script:ResourceTypes[$Resource.Type]
    if (-not $Abbreviation) { $Abbreviation = $meta.Abbreviation }
    if (-not $Abbreviation) { return ConvertTo-HclString $Resource.Key }
    if ($Resource.Type -eq 'storage_account') {
        return '"' + $Abbreviation + '${local.org}${local.workload}${var.environment}${local.region_abbr}"'
    }
    $component = if ($meta.Component) { '-' + $Resource.Key } else { '' }
    return '"' + $Abbreviation + '-${local.org}-${local.workload}' + $component + '-${var.environment}-${local.region_abbr}"'
}

function Get-FieldHcl {
    <# HCL for a spec field. A per-environment map becomes a Terraform variable; anything else is a literal. #>
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)]$Resource, [Parameter(Mandatory)][string]$Field, $Default)

    $value = $Resource.Data[$Field]
    if ($null -eq $value) {
        if (-not $PSBoundParameters.ContainsKey('Default')) { throw "$($Resource.Type) '$($Resource.Key)' is missing required field '$Field'." }
        $value = $Default
    }
    if (Test-IsEnvironmentMap $value) {
        $name = if ($Resource.Key) { '{0}_{1}_{2}' -f $Resource.Type, $Resource.Label, $Field } else { '{0}_{1}' -f $Resource.Type, $Field }
        $Context.Variables[$name] = [pscustomobject]@{
            Name        = $name
            Type        = $script:TunableFields[$Resource.Type][$Field]
            Description = ('{0} {1}: {2}, set per environment.' -f $Resource.Type, $Resource.Key, $Field).Replace(' : ', ': ')
            Values      = $value
        }
        return "var.$name"
    }
    return ConvertTo-HclValue $value
}

function Get-TagsReference { return 'local.tags' }

function Resolve-SettingHcl {
    <# HCL for one `settings:` entry: either a literal value or a reference such as app_configuration.endpoint. #>
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)]$Setting)
    if ($Setting.Contains('from')) {
        $sourceType, $attribute = $Setting['from'].Split('.', 2)
        $address = Get-SingletonAddress -Context $Context -Type $sourceType
        return $script:ExposedAttributes[$sourceType][$attribute].Replace('@ADDR@', $address)
    }
    return ConvertTo-HclValue $Setting['value']
}

function Get-SettingsSorted {
    param($Resource)
    $items = [System.Collections.Generic.List[object]]::new()
    foreach ($setting in @($Resource.Data['settings'])) { if ($null -ne $setting) { $items.Add($setting) } }
    $items.Sort([System.Comparison[object]]{ param($a, $b) [string]::CompareOrdinal($a['name'], $b['name']) })
    return $items.ToArray()
}

function Get-CommonAttributes {
    <# name, location, resource_group_name, tags: the four lines most azurerm resources start with. #>
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)]$Resource)
    return @(
        (New-HclAttr 'name' ('local.names.' + (Get-NameId $Resource)))
        (New-HclAttr 'location' 'local.region')
        (New-HclAttr 'resource_group_name' ((Get-SingletonAddress $Context 'resource_group') + '.name'))
    )
}

function Add-OutputDefinition {
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Value, [Parameter(Mandatory)][string]$Description, [switch]$Sensitive)
    $Context.Outputs[$Name] = [pscustomobject]@{ Name = $Name; Value = $Value; Description = $Description; Sensitive = [bool]$Sensitive }
}
