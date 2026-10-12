# Hcl.ps1
# Tiny helpers that turn values into HCL text. Output is already formatted the way
# `terraform fmt` formats it, so the generator needs no formatting pass.

function ConvertTo-HclString {
    <# Quotes a literal string for HCL and escapes characters HCL treats specially. #>
    param([Parameter(Mandatory)][string]$Value)
    $escaped = $Value.Replace('\', '\\').Replace('"', '\"').Replace('${', '$${').Replace('%{', '%%{').Replace("`n", '\n')
    return '"' + $escaped + '"'
}

function ConvertTo-HclValue {
    <# Converts a scalar or list from the spec into an HCL literal. #>
    param($Value)
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [bool]) { return $Value.ToString().ToLowerInvariant() }
    if ($Value -is [string]) { return ConvertTo-HclString $Value }
    if ($Value -is [System.Collections.IList]) {
        $items = foreach ($item in $Value) { ConvertTo-HclValue $item }
        return '[' + (@($items) -join ', ') + ']'
    }
    return [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0}', $Value)
}

function Get-SortedKeys {
    <# Ordinal (culture-independent) sort, so output never depends on the machine's locale. #>
    param([Parameter(Mandatory)]$Dictionary)
    $keys = [string[]]@($Dictionary.Keys)
    [System.Array]::Sort($keys, [System.StringComparer]::Ordinal)
    return $keys
}

# --- Body items ---------------------------------------------------------------------------

function New-HclAttr {
    <# One `name = value` line. -Value is HCL text (use ConvertTo-HclValue for literals). #>
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Value)
    [pscustomobject]@{ Kind = 'attr'; Name = $Name; Value = $Value }
}

function New-HclMap {
    <# A multi-line `name = { key = value ... }` attribute. -Entries maps key -> HCL text. #>
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)]$Entries)
    [pscustomobject]@{ Kind = 'map'; Name = $Name; Entries = $Entries }
}

function New-HclBlock {
    <# A nested block, e.g. identity { ... }. -Body is an array of items from this file. #>
    param([Parameter(Mandatory)][string]$Name, [object[]]$Body = @())
    [pscustomobject]@{ Kind = 'block'; Name = $Name; Body = @($Body) }
}

# --- Rendering ------------------------------------------------------------------------------

function Format-HclBody {
    param([object[]]$Items, [int]$Indent = 1)
    $pad = '  ' * $Indent
    $lines = [System.Collections.Generic.List[string]]::new()
    $i = 0
    $previousKind = $null
    while ($i -lt $Items.Count) {
        $item = $Items[$i]
        if ($item.Kind -eq 'attr') {
            # A run of consecutive single-line attributes is aligned on '=' (what terraform fmt does).
            $run = @()
            while ($i -lt $Items.Count -and $Items[$i].Kind -eq 'attr') { $run += $Items[$i]; $i++ }
            if ($null -ne $previousKind) { $lines.Add('') }
            $width = ($run | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum
            foreach ($attr in $run) { $lines.Add($pad + $attr.Name.PadRight($width) + ' = ' + $attr.Value) }
            $previousKind = 'attr'
            continue
        }
        if ($null -ne $previousKind) { $lines.Add('') }
        if ($item.Kind -eq 'map') {
            $lines.Add($pad + $item.Name + ' = {')
            $keys = Get-SortedKeys $item.Entries
            $width = ($keys | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
            foreach ($key in $keys) { $lines.Add($pad + '  ' + $key.PadRight($width) + ' = ' + $item.Entries[$key]) }
            $lines.Add($pad + '}')
        }
        elseif ($item.Kind -eq 'block') {
            if ($item.Body.Count -eq 0) { $lines.Add($pad + $item.Name + ' {}') }
            else {
                $lines.Add($pad + $item.Name + ' {')
                foreach ($line in (Format-HclBody -Items $item.Body -Indent ($Indent + 1))) { $lines.Add($line) }
                $lines.Add($pad + '}')
            }
        }
        $previousKind = $item.Kind
        $i++
    }
    return $lines.ToArray()
}

function New-HclTopLevelBlock {
    param([Parameter(Mandatory)][string]$Header, [object[]]$Body = @())
    $lines = @($Header + ' {') + (Format-HclBody -Items $Body) + @('}')
    return ($lines -join "`n")
}

function New-HclResource {
    param([Parameter(Mandatory)][string]$TerraformType, [Parameter(Mandatory)][string]$Label, [object[]]$Body)
    New-HclTopLevelBlock -Header ('resource "{0}" "{1}"' -f $TerraformType, $Label) -Body $Body
}

function New-HclSectionBanner {
    param([Parameter(Mandatory)][string]$Title)
    $rule = '# ' + ('-' * 76)
    return ($rule, "# $Title", $rule) -join "`n"
}
