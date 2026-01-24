<#
.SYNOPSIS
  Main script.

.DESCRIPTION
  Orchestrates the extraction of all the files.,

.PARAMETER Path
  Path to the input XML file (e.g., Transport TagData.xml).

.PARAMETER OutPath
  Output directory path where all files will be exported.

.PARAMETER IncludeEmptyValues
  If set, includes columns even when their value is empty. Default: off.

.PARAMETER PreviewXml
  If set, prints the generated XML to the console.

.PARAMETER CSVMode
  If set, generates schema-only XML files with @placeholders@ and separate CSV files per table.

.PARAMETER ApiBaseUrl
  Base URL for the OIM API. Default: http://localhost:8182

.PARAMETER ApiModule
  OIM module name for authentication. Default: SupportPlus

.PARAMETER ApiUser
  Username for API authentication. Default: viadmin

.PARAMETER ApiPassword
  Password for API authentication. Default: P@ssword.123

.EXAMPLE
  .\Main.ps1 -Path "C:\Input\tagdata.xml" -OutPath "C:\Output"

.EXAMPLE
  .\Main.ps1 -Path "C:\Input\tagdata.xml" -OutPath "C:\Output" -CSVMode

.EXAMPLE
  .\Main.ps1 -Path "C:\Input\tagdata.xml" -OutPath "C:\Output" -CSVMode -PreviewXml
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$Path,

  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$OutPath,

  [switch]$IncludeEmptyValues,
  [switch]$PreviewXml,
  [switch]$CSVMode,

  [string]$ApiBaseUrl = "http://localhost:8182",
  [string]$ApiModule  = "SupportPlus",
  [string]$ApiUser    = "viadmin",
  [string]$ApiPassword = "Password.123"
)

# --- Load config.json defaults (only for params not explicitly passed) ---
$scriptDir   = $PSScriptRoot
$configPath  = Join-Path $scriptDir 'config.json'

if (Test-Path -LiteralPath $configPath) {
  try {
    $cfg = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json

    if (-not $PSBoundParameters.ContainsKey('ApiBaseUrl') -and $cfg.ApiBaseUrl) { $ApiBaseUrl = [string]$cfg.ApiBaseUrl }
    if (-not $PSBoundParameters.ContainsKey('ApiModule')  -and $cfg.ApiModule)  { $ApiModule  = [string]$cfg.ApiModule  }
    if (-not $PSBoundParameters.ContainsKey('ApiUser')    -and $cfg.ApiUser)    { $ApiUser    = [string]$cfg.ApiUser    }
    if (-not $PSBoundParameters.ContainsKey('ApiPassword') -and $cfg.ApiPassword) { $ApiPassword = [string]$cfg.ApiPassword }

  } catch {
    throw "Failed to read/parse config.json at '$configPath': $($_.Exception.Message)"
  }
}

#region Module Imports
$modulesDir = Join-Path $scriptDir "Modules"

Import-Module (Join-Path $modulesDir "DBObjects/DBObjects_Main.psm1") -Force
Import-Module (Join-Path $modulesDir "Templates/Templates_Main.psm1") -Force
Import-Module (Join-Path $modulesDir "ExtractXMLFromZip.psm1") -Force
#endregion

#region Main Execution
$zipPath  = $Path
$resolved = Resolve-TagDataXmlFromZip -ZipPath $zipPath
$Path     = $resolved.TagDataXmlPath

DBObjects_Main -Path $Path -OutPath $OutPath -ApiBaseUrl $ApiBaseUrl -ApiModule $ApiModule -ApiUser $ApiUser -ApiPassword $ApiPassword
Templates_Main -Path $Path -OutPath $OutPath -ApiBaseUrl $ApiBaseUrl -ApiModule $ApiModule -ApiUser $ApiUser -ApiPassword $ApiPassword
#endregion
