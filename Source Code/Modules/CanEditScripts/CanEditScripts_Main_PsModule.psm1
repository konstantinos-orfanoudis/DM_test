<#
.SYNOPSIS
  Main script to export OIM Scripts from TagData XML files.

.DESCRIPTION
  Orchestrates the extraction of Scripts from OIM Transport XML files.

.PARAMETER Path
  Path to the input XML file (e.g., Transport TagData.xml).

.PARAMETER OutPath
  Output directory path where all files will be exported.

.PARAMETER ConfigDir
  Configuration directory for OIM connection.

.PARAMETER LogPath
  Optional log file path. If not provided, defaults to OutPath\Logs\export.log

.PARAMETER DMDll
  Path to the Deployment Manager DLL.

.EXAMPLE
  Scripts_Main_PsModule -Path "C:\Input\tagdata.xml" -OutPath "C:\Output" -ConfigDir "C:\Config" -DMDll "C:\DM.dll"
#>

function CanEditScripts_Main_PsModule{
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

# Import all required modules
Import-Module (Join-Path $scriptDir "CanEditScripts_XmlParser.psm1") -Force
Import-Module (Join-Path $commonDir "PsModuleLogin.psm1") -Force
Import-Module (Join-Path $scriptDir "CanEditScripts_Exporter_PsModule.psm1") -Force
#endregion

#region Main Execution
try {
  $Logger = Get-Logger
  $Logger.Info("OIM CanEdit Scripts Export Tool")

  # Step 1: Parse input XML
  $Logger.Info("Parsing input XML: $ZipPath")
  $caneditscripts = Get-CanEditScriptsFromChangeLabel -ZipPath $ZipPath

  Write-Host "  Found $($caneditscripts.Count) CanEditScript(s)" -ForegroundColor Cyan
  $Logger.Info("Found $($caneditscripts.Count) CanEditScript(s)")

  # Report mode: if any stale abort was triggered during parsing, print report and exit
  if ($global:XDateCheck_StaleAbortTriggered) {
    Write-Host "  [REPORT MODE] Stale object abort triggered - no files will be written." -ForegroundColor Yellow
    $Logger.Info("[REPORT MODE] Stale object abort triggered - no files will be written.")
    foreach ($k in $caneditscripts) { Write-Host "    - $k" -ForegroundColor Gray }
    return
  }

  if ($caneditscripts.Count -gt 0) {
    # Step 2: Login to API
    $Logger.Info("Opening session with DMConfigDir: $DMConfigDir")
    $session = Connect-OimPSModule -DMConfigDir $DMConfigDir -DMDll $DMDll -OutPath $OutPath -DMPassword $DMPassword
    $Logger = Get-Logger
    $Logger.Info("Authentication successful")

    # Step 3: Export Scripts
    $outDirScripts = Join-Path -Path $OutPath -ChildPath "CanEditScripts"
    Write-Host "  Exporting to: $outDirScripts" -ForegroundColor Gray
    $Logger.Info("Exporting to: $outDirScripts")
    Write-CanEditScriptsAsVbNetFiles -CanEditScripts $caneditscripts -OutDir $outDirScripts
    $Logger.Info("Export completed successfully!")
  }
  else {
    $Logger = Get-Logger
    Write-Host "  No CanEditScripts found in: $ZipPath" -ForegroundColor Yellow
    $Logger.Info("No CanEditScripts found in: $ZipPath")
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

# Export module members
Export-ModuleMember -Function @(
  'CanEditScripts_Main_PsModule'
)
