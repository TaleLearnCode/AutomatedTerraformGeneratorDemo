#Requires -Version 7.0
<#
.SYNOPSIS
    Turns an infrastructure spec (YAML) into a plain azurerm Terraform configuration.

.DESCRIPTION
    The same spec always produces byte-identical files. The script does no interpretation: it
    validates the spec, then each script in Actions/ writes the Terraform for one resource type.

    Output (in -OutputPath):
        providers.tf  variables.tf  locals.tf  main.tf  outputs.tf
        environments/<env>.tfvars  environments/<env>.backend.hcl

.PARAMETER SpecPath
    The YAML spec, for example ../infra/work-item-service.infra.yaml

.PARAMETER OutputPath
    Folder for the generated Terraform. Created if missing. Defaults to ./terraform

.PARAMETER SchemaPath
    JSON Schema used to validate the spec. Defaults to schema/infra-spec.schema.json beside this script.

.EXAMPLE
    ./New-TerraformConfiguration.ps1 -SpecPath ./examples/work-item-service/work-item-service.infra.yaml -OutputPath ./out
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SpecPath,
    [string]$OutputPath = (Join-Path (Get-Location) 'terraform'),
    [string]$SchemaPath = (Join-Path $PSScriptRoot 'schema/infra-spec.schema.json')
)

$ErrorActionPreference = 'Stop'

# Load helpers and actions. A foreach statement (not ForEach-Object) keeps the functions in this scope.
foreach ($file in (Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private'), (Join-Path $PSScriptRoot 'Actions') -Filter '*.ps1' | Sort-Object FullName)) {
    . $file.FullName
}

function ConvertTo-PascalCase { param([string]$Value) return (($Value -split '_') | ForEach-Object { $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1) }) -join '' }

# 1. Read and validate the spec.
$SpecPath = (Resolve-Path -LiteralPath $SpecPath).Path
$parsed = Read-InfraSpec -Path $SpecPath
Assert-InfraSpecSchema -Spec $parsed.Spec -SchemaPath $SchemaPath
Assert-InfraSpecSemantics -Spec $parsed.Spec
Write-Host "Spec OK: $(Split-Path -Leaf $SpecPath)"

# 2. Build the context and run one action per resource.
$context = New-GenerationContext -Spec $parsed.Spec -SpecFileName (Split-Path -Leaf $SpecPath) -SpecSha256 $parsed.Sha256

$mainSections = [System.Collections.Generic.List[string]]::new()
if ($context.Index.Keys | Where-Object { $_ -like 'key_vault/*' }) {
    $mainSections.Add('data "azurerm_client_config" "current" {}')
}

$resourceCount = 0
foreach ($type in $script:ResourceTypes.Keys) {
    $ofType = @($context.Resources | Where-Object { $_.Type -eq $type })
    if ($ofType.Count -eq 0) { continue }
    $action = 'New-{0}Hcl' -f (ConvertTo-PascalCase $type)
    if (-not (Get-Command $action -ErrorAction SilentlyContinue)) { throw "No action script defines $action for resource type '$type'." }

    $mainSections.Add((New-HclSectionBanner $type))
    foreach ($resource in $ofType) {
        foreach ($block in @(& $action -Context $context -Resource $resource)) { $mainSections.Add($block) }
        $resourceCount++
    }
}

$grants = @($context.Spec['access'] | Where-Object { $null -ne $_ })
if ($grants.Count -gt 0) {
    $mainSections.Add((New-HclSectionBanner 'access: role assignments'))
    foreach ($grant in $grants) { $mainSections.Add((New-RoleAssignmentHcl -Context $context -Grant $grant)) }
}

$withDiagnostics = @($context.Resources | Where-Object { $script:DiagnosticTypes -contains $_.Type -and $_.Data['diagnostics'] })
if ($withDiagnostics.Count -gt 0) {
    $mainSections.Add((New-HclSectionBanner 'diagnostics: send logs and metrics to Log Analytics'))
    foreach ($resource in $withDiagnostics) { $mainSections.Add((New-DiagnosticSettingHcl -Context $context -Resource $resource)) }
}

# 3. Write the files. Variables and outputs are complete only after every action has run.
$header = Get-GeneratedHeader -Context $context
$files = [ordered]@{
    'providers.tf' = New-ProvidersFile
    'variables.tf' = New-VariablesFile -Context $context
    'locals.tf'    = New-LocalsFile -Context $context
    'main.tf'      = ($mainSections -join "`n`n")
    'outputs.tf'   = New-OutputsFile -Context $context
}
foreach ($name in $files.Keys) {
    Write-GeneratedFile -Path (Join-Path $OutputPath $name) -Content ($header + "`n`n" + $files[$name])
}
foreach ($environment in $context.Environments) {
    Write-GeneratedFile -Path (Join-Path $OutputPath "environments/$environment.tfvars") -Content ($header + "`n`n" + (New-TfVarsFile -Context $context -Environment $environment))
    Write-GeneratedFile -Path (Join-Path $OutputPath "environments/$environment.backend.hcl") -Content ($header + "`n`n" + (New-BackendFile -Context $context -Environment $environment))
}

$placeholders = @($parsed.Spec['state'].Values | Where-Object { $_ -like 'REPLACE_*' })
if ($placeholders.Count -gt 0) {
    Write-Warning 'The spec still has placeholder remote-state values. Platform Engineering supplies them before the first apply (IG-021).'
}
Write-Host ("Generated {0} resources into {1}" -f $resourceCount, (Resolve-Path -LiteralPath $OutputPath).Path)
