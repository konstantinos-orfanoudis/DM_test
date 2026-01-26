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

.PARAMETER Config

  .PARAMETER DMDll
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

  [Parameter(Mandatory)]
    [string]$ConfigDir,

    [Parameter(Mandatory)]
    [string]$DMDll
)

# --- Load config.json defaults (only for params not explicitly passed) ---
$scriptDir   = $PSScriptRoot
$configPath  = Join-Path $scriptDir 'config.json'

if (Test-Path -LiteralPath $configPath) {
  try {
    

    

  } catch {
    throw "Failed to read/parse config.json at '$configPath': $($_.Exception.Message)"
  }
}

#region Module Imports
$modulesDir = Join-Path $scriptDir "Modules"

Import-Module (Join-Path $modulesDir "DBObjects/DBObjects_Main_PsModule.psm1") -Force
Import-Module (Join-Path $modulesDir "Templates/Templates_Main.psm1") -Force
Import-Module (Join-Path $modulesDir "ExtractXMLFromZip.psm1") -Force
#endregion

#region Main Execution
$zipPath  = $Path
$resolved = Resolve-TagDataXmlFromZip -ZipPath $zipPath
$Path     = $resolved.TagDataXmlPath

DBObjects_Main_PsModule -Path $Path -OutPath $OutPath -ConfigDir $ConfigDir -DMDll $DMDll
Templates_Main -Path $Path -OutPath $OutPath -ApiBaseUrl $ApiBaseUrl -ApiModule $ApiModule -ApiUser $ApiUser -ApiPassword $ApiPassword
#endregion
