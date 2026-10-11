#Requires -Version 7.0
<#
.SYNOPSIS
    Checks the generator without Pester or any other test framework.

.DESCRIPTION
    1. Generates the example twice and requires byte-identical output (IG-018).
    2. Requires the committed example output to match a fresh generation (no drift).
    3. Requires every resource in the spec to appear in main.tf.
    4. Requires known-bad specs to be rejected with a useful message.
    5. Runs `terraform fmt -check` (or `tofu fmt -check`) when either is installed.

    Requires the powershell-yaml module (Install-Module powershell-yaml -Scope CurrentUser).
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$generator = Join-Path $root 'New-TerraformConfiguration.ps1'
$exampleDir = Join-Path $root 'examples/work-item-service'
$spec = Join-Path $exampleDir 'work-item-service.infra.yaml'
$work = Join-Path ([System.IO.Path]::GetTempPath()) ('tfgen-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null

$failures = [System.Collections.Generic.List[string]]::new()
function Assert-That { param([string]$Name, [bool]$Condition, [string]$Detail = '')
    if ($Condition) { Write-Host "  PASS  $Name" -ForegroundColor Green }
    else { Write-Host "  FAIL  $Name $Detail" -ForegroundColor Red; $script:failures.Add($Name) }
}
function Get-FolderHashes { param([string]$Path)
    Get-ChildItem -LiteralPath $Path -Recurse -File | Sort-Object FullName | ForEach-Object {
        '{0} {1}' -f [System.IO.Path]::GetRelativePath($Path, $_.FullName).Replace('\', '/'), (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }
}
function Invoke-Generator { param([string]$SpecPath, [string]$OutputPath)
    & $generator -SpecPath $SpecPath -OutputPath $OutputPath 3>$null 6>$null | Out-Null
}

try {
    Write-Host 'Determinism and drift'
    Invoke-Generator $spec (Join-Path $work 'a')
    Invoke-Generator $spec (Join-Path $work 'b')
    $hashesA = (Get-FolderHashes (Join-Path $work 'a')) -join "`n"
    $hashesB = (Get-FolderHashes (Join-Path $work 'b')) -join "`n"
    Assert-That 'two runs produce identical files' ($hashesA -eq $hashesB)
    $committed = Join-Path $exampleDir 'terraform'
    $hashesCommitted = if (Test-Path $committed) { (Get-FolderHashes $committed) -join "`n" } else { '' }
    Assert-That 'committed example output matches a fresh run' ($hashesA -eq $hashesCommitted) 'Run the generator on the example and commit the result.'

    Write-Host 'Coverage'
    . (Join-Path $root 'Private/Hcl.ps1'); . (Join-Path $root 'Private/ResourceTypes.ps1')
    $main = Get-Content -Raw (Join-Path $work 'a/main.tf')
    Import-Module powershell-yaml -ErrorAction SilentlyContinue
    $parsed = ConvertFrom-Yaml (Get-Content -Raw $spec)
    foreach ($entry in $parsed['resources']) {
        $terraformType = $script:ResourceTypes[$entry['type']].Terraform
        $label = if ($entry['key']) { ($entry['key'].ToLowerInvariant() -replace '[^a-z0-9]', '_') } else { 'main' }
        Assert-That "main.tf declares $($entry['type'])$(if ($entry['key']) { '/' + $entry['key'] })" ($main -match ('resource "{0}" "{1}"' -f $terraformType, $label))
    }
    Assert-That 'every access entry has a role assignment' (([regex]::Matches($main, 'resource "azurerm_(cosmosdb_sql_)?role_assignment"')).Count -eq @($parsed['access']).Count)
    Assert-That 'every diagnostics: true resource has a diagnostic setting' (([regex]::Matches($main, 'resource "azurerm_monitor_diagnostic_setting"')).Count -eq @($parsed['resources'] | Where-Object { $_['diagnostics'] }).Count)
    Assert-That 'no key or connection string is written into the output' (-not ($main -match 'primary_access_key|primary_connection_string|primary_key'))
    foreach ($environment in $parsed['environments']) {
        Assert-That "environments/$environment.tfvars and .backend.hcl exist" ((Test-Path (Join-Path $work "a/environments/$environment.tfvars")) -and (Test-Path (Join-Path $work "a/environments/$environment.backend.hcl")))
    }

    Write-Host 'Schema stays in step with the scripts'
    $schema = Get-Content -Raw (Join-Path $root 'schema/infra-spec.schema.json') | ConvertFrom-Json -AsHashtable
    Assert-That 'schema lists exactly the known resource types' ((($schema.properties.resources.items.properties.type.enum | Sort-Object) -join ',') -eq (($script:ResourceTypes.Keys | Sort-Object) -join ','))
    Assert-That 'schema lists exactly the known roles' ((($schema.properties.access.items.properties.role.enum | Sort-Object) -join ',') -eq (($script:Roles.Keys | Sort-Object) -join ','))
    foreach ($type in $script:ResourceTypes.Keys) {
        $action = 'Actions/' + ((($type -split '_') | ForEach-Object { $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1) }) -join '') + '.ps1'
        Assert-That "action script exists for $type" (Test-Path (Join-Path $root $action)) $action
    }

    Write-Host 'Bad specs are rejected'
    $original = Get-Content -Raw $spec
    $badCases = [ordered]@{
        'unknown subscription topic'        = @{ From = 'topic: work-item-events'; To = 'topic: no-such-topic'; Expect = 'not defined' }
        'incomplete per-environment map'    = @{ From = 'retention_in_days: { dev: 30, qa: 30, prd: 90 }'; To = 'retention_in_days: { dev: 30, prd: 90 }'; Expect = 'exactly these environments' }
        'per-environment map on a fixed field' = @{ From = 'sku: Standard'; To = 'sku: { dev: Standard, qa: Standard, prd: Standard }'; Expect = 'schema' }
        'misspelled field'                  = @{ From = 'purge_protection:'; To = 'purge_protecton:'; Expect = 'schema' }
        'unknown resource type'             = @{ From = 'type: key_vault'; To = 'type: key_vaults'; Expect = 'schema' }
        'role on the wrong scope'           = @{ From = 'role: Key Vault Secrets User, scope: key_vault }'; To = 'role: Key Vault Secrets User, scope: app_configuration }'; Expect = 'cannot be scoped' }
        'environment tag set by hand'       = @{ From = '  managed_by: terraform'; To = "  managed_by: terraform`n  environment: dev"; Expect = "must not define 'environment'" }
    }
    $i = 0
    foreach ($name in $badCases.Keys) {
        $case = $badCases[$name]; $i++
        $badPath = Join-Path $work "bad$i.infra.yaml"
        $changed = $original.Replace($case.From, $case.To)
        [System.IO.File]::WriteAllText($badPath, $changed)
        $message = ''
        try { Invoke-Generator $badPath (Join-Path $work "bad$i") } catch { $message = $_.Exception.Message }
        Assert-That "rejects: $name" (($changed -ne $original) -and $message -match [regex]::Escape($case.Expect)) "(got: $message)"
    }

    Write-Host 'Formatting'
    $formatter = @('terraform', 'tofu') | Where-Object { Get-Command $_ -ErrorAction SilentlyContinue } | Select-Object -First 1
    if ($formatter) {
        & $formatter fmt -check -recursive (Join-Path $work 'a') | Out-Null
        Assert-That "$formatter fmt -check passes" ($LASTEXITCODE -eq 0)
    }
    else { Write-Host '  SKIP  terraform/tofu not installed' -ForegroundColor Yellow }
}
finally { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }

if ($failures.Count -gt 0) { Write-Host "`n$($failures.Count) check(s) failed." -ForegroundColor Red; exit 1 }
Write-Host "`nAll checks passed." -ForegroundColor Green
