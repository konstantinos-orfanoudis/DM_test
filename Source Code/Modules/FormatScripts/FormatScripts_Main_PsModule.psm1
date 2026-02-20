<#
.SYNOPSIS
  Main script to export formatted OIM Scripts from TagData XML files.

.DESCRIPTION
  Orchestrates the extraction and formatting of OIM Scripts from Transport XML files.

.PARAMETER ZipPath
  Path to the input XML / ZIP file (Transport TagData.xml).

.PARAMETER OutPath
  Output directory path where all files will be exported.

.PARAMETER DMConfigDir
  Configuration directory for OIM connection.

.PARAMETER LogPath
  Optional log file path (kept for signature compatibility).

.PARAMETER DMDll
  Path to the Deployment Manager DLL.
#>

function FormatScripts_Main_PsModule {
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [ValidateNotNullOrEmpty()]
  [string]$ZipPath,

  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$OutPath,

  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$DMConfigDir,

  [Parameter(Mandatory = $false)]
  [string]$LogPath = "",

  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$DMDll,

  [Parameter(Mandatory = $false)]
  [switch]$CSVMode,

  [Parameter(Mandatory = $false)]
  [switch]$IncludeEmptyValues,

  [Parameter(Mandatory = $false)]
  [string]$DMPassword = "",

  [Parameter(Mandatory = $false)]
  [string]$TableNameMapCSV = ""
)

#region Module Imports
$scriptDir = $PSScriptRoot
$modulesDir = Split-Path -Parent $PSScriptRoot
$commonDir = Join-Path $modulesDir "Common"

Import-Module (Join-Path $scriptDir "FormatScripts_XmlParser.psm1") -Force
Import-Module (Join-Path $commonDir "PsModuleLogin.psm1") -Force
Import-Module (Join-Path $scriptDir "FormatScripts_Exporter_PsModule.psm1") -Force
#endregion

#region Main Execution
try {
  $Logger = Get-Logger
  $Logger.Info("OIM Format Scripts Export Tool")

  # Step 1: Parse input XML
  $Logger.Info("Parsing input XML: $ZipPath")
  $scripts = Get-FormatScriptKeysFromChangeLabel -ZipPath $ZipPath

  Write-Host "  Found $($scripts.Count) FormatScript(s)" -ForegroundColor Cyan
  $Logger.Info("Found $($scripts.Count) FormatScript(s)")

  # Report mode: if any stale abort was triggered during parsing, print report and exit
  if ($global:XDateCheck_StaleAbortTriggered) {
    Write-Host "  [REPORT MODE] Stale object abort triggered - no files will be written." -ForegroundColor Yellow
    $Logger.Info("[REPORT MODE] Stale object abort triggered - no files will be written.")
    foreach ($k in $scripts) { Write-Host "    - $k" -ForegroundColor Gray }
    return
  }

  if ($scripts.Count -gt 0) {
    # Step 2: Login to API
    $Logger.Info("Opening session with DMConfigDir: $DMConfigDir")
    $session = Connect-OimPSModule -DMConfigDir $DMConfigDir -DMDll $DMDll -OutPath $OutPath -DMPassword $DMPassword
    $Logger = Get-Logger
    $Logger.Info("Authentication successful")

    # Step 3: Export Format Scripts
    $outDirScripts = Join-Path -Path $OutPath -ChildPath "FormatScripts"
    Write-Host "  Exporting to: $outDirScripts" -ForegroundColor Gray
    $Logger.Info("Exporting to: $outDirScripts")
    Write-FormatScriptsAsVbNetFiles -Scripts $scripts -OutDir $outDirScripts
    $Logger.Info("Export completed successfully!")
  }
  else {
    $Logger = Get-Logger
    Write-Host "  No FormatScripts found in: $ZipPath" -ForegroundColor Yellow
    $Logger.Info("No FormatScripts found in: $ZipPath")
  }
}
catch {
  $Logger = Get-Logger
  $Logger.Info("ERROR: Export failed!")
  $Logger.Info($_.Exception.Message)
  Write-Host "  ERROR: Export failed!" -ForegroundColor Red
  Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
  if ($_.ScriptStackTrace) {
    $Logger = Get-Logger
    $Logger.Info("Stack Trace:")
    $Logger.Info($_.ScriptStackTrace)
    Write-Host "  Stack Trace:" -ForegroundColor Yellow
    Write-Host "  $($_.ScriptStackTrace)" -ForegroundColor Yellow
  }
  throw
}
#endregion
}

Export-ModuleMember -Function @(
  'FormatScripts_Main_PsModule'
)
