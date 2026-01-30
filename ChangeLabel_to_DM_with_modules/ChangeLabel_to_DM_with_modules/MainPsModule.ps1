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
  [string]$ZipPath,

  [string]$DMConfigDir,
  [string]$OutPath,
  [switch]$IncludeEmptyValues,
  [switch]$PreviewXml,
  [switch]$CSVMode,
  [string]$DMDll
     
)

# --- Load config.json defaults (only for params not explicitly passed) ---
$scriptDir   = $PSScriptRoot




#region Module Imports
$modulesDir = Join-Path $scriptDir "Modules"

Import-Module (Join-Path $modulesDir "DBObjects/DBObjects_Main_PsModule.psm1") -Force
Import-Module (Join-Path $modulesDir "Process/Process_Main_PsModule.psm1") -Force
Import-Module (Join-Path $modulesDir "Templates/Templates_Main_PsModule.psm1") -Force
Import-Module (Join-Path $modulesDir "Scripts/Scripts_Main_PsModule.psm1") -Force
Import-Module (Join-Path $modulesDir "ExtractXMLFromZip.psm1") -Force
Import-Module (Join-Path $scriptDir "InputValidator.psm1") -Force
#endregion

#region Main Execution
$resolved = Resolve-TagDataXmlFromZip -ZipPath $ZipPath
write-Host $resolved




$config = InputValidator -DMConfigDir $DMConfigDir -OutPath $OutPath -LogPath $LogPath -IncludeEmptyValues $IncludeEmptyValues  -PreviewXml $PreviewXml -CSVMode $CSVMode -DMDll $DMDll
  foreach($Path in  $resolved){

    DBObjects_Main_PsModule -Path $Path.TagDataXmlPath -OutPath $config.OutPath -LogPath $config.LogPath -ConfigDir $config.ConfigDir -DMDll $config.DMDll
    Process_Main_PsModule -Path $Path.TagDataXmlPath -OutPath $config.OutPath -LogPath $config.LogPath -ConfigDir $config.ConfigDir -DMDll $config.DMDll
    Templates_Main_PsModule -Path $Path.TagDataXmlPath -OutPath $config.OutPath -LogPath $config.LogPath -ConfigDir $config.ConfigDir -DMDll $config.DMDll
    Scripts_Main_PsModule -Path $Path.TagDataXmlPath -OutPath $config.OutPath -LogPath $config.LogPath -ConfigDir $config.ConfigDir -DMDll $config.DMDll
  }
#endregion


