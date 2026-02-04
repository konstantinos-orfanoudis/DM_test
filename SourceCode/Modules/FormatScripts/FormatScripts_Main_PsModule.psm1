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
  [string]$DMDll
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
  Write-Host "OIM Format Scripts Export Tool" -ForegroundColor Cyan
  Write-Host ""

  # Step 1: Parse input XML
  Write-Host "[1/3] Parsing input XML: $ZipPath"
  $scripts = Get-FormatScriptKeysFromChangeLabel -ZipPath $ZipPath

  Write-Host "Found $($scripts.Count) Format script(s)" -ForegroundColor Cyan

  if ($scripts.Count -gt 0) {

    # Step 2: Login (kept for parity / future use)
    Write-Host "[2/3] Opening session with DMConfigDir: $DMConfigDir"
    $session = Connect-OimPSModule -DMConfigDir $DMConfigDir -DMDll $DMDll -OutPath $OutPath
    Write-Host "Authentication successful"
    Write-Host ""

    # Step 3: Export formatted scripts
    Write-Host "[3/3] Exporting formatted scripts to: $OutPath"
    $outDirScripts = Join-Path -Path $OutPath -ChildPath "FormatScripts"
    Write-FormatScriptsAsVbNetFiles -Scripts $scripts -OutDir $outDirScripts

    Write-Host ""
    Write-Host "Export completed successfully!" -ForegroundColor Green
  }
  else {
    Write-Host "No scripts found in ChangeContent in: $ZipPath" -ForegroundColor Yellow
  }
}
catch {
  Write-Host ""
  Write-Host "ERROR: Export failed!" -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red

  if ($_.ScriptStackTrace) {
    Write-Host ""
    Write-Host "Stack Trace:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
  }
  throw
}
#endregion
}

Export-ModuleMember -Function @(
  'FormatScripts_Main_PsModule'
)
