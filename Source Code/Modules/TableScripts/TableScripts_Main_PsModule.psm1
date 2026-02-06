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

function TableScripts_Main_PsModule{
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

# Import all required modules
Import-Module (Join-Path $scriptDir "TableScripts_XmlParser.psm1") -Force
Import-Module (Join-Path $commonDir "PsModuleLogin.psm1") -Force
Import-Module (Join-Path $scriptDir "TableScripts_Exporter_PsModule.psm1") -Force
#endregion

#region Main Execution
try {
  $Logger = Get-Logger
  $Logger.Info(" OIM Table Scripts Export Tool")
  Write-Host "OIM Table Scripts Export Tool" -ForegroundColor Cyan
  Write-Host ""

  # Step 1: Parse input XML
  Write-Host "[1/3] Parsing input XML: $ZipPath"
  $Logger.Info("Parsing input XML: $ZipPath")
  $Tablescripts = Get-DialogTableScriptsFromChangeLabel -ZipPath $ZipPath 

  Write-Host "Found $($Tablescripts.Count) Tablescript(s)" -ForegroundColor Cyan
  $Logger.Info("Found $($Tablescripts.Count) Tablescript(s)")

  if ($Tablescripts.Count -gt 0) {
    # Step 2: Login to API
    Write-Host "[2/3] Opening session with DMConfigDir: $DMConfigDir"
    $Logger.Info("Opening session with DMConfigDir: $DMConfigDir")
    $session = Connect-OimPSModule -DMConfigDir $DMConfigDir -DMDll $DMDll -OutPath $OutPath
    $Logger = Get-Logger
    $Logger.Info("Authentication successful")
    Write-Host "Authentication successful"
    Write-Host ""
    
    # Step 3: Export Scripts
    Write-Host "[3/3] Exporting to: $OutPath"
    $Logger.Info("Exporting to: $OutPath")
    $outDirScripts = Join-Path -Path $OutPath -ChildPath "TableScripts"
    Write-TableScriptsAsVbNetFiles -Scripts $Tablescripts -OutDir $outDirScripts
    $Logger.Info("Export completed successfully!")
    
    Write-Host ""
    Write-Host "Export completed successfully!" -ForegroundColor Green
  } 
  else {
    Write-Host "No TableScripts found in ChangeContent in: $ZipPath" -ForegroundColor Yellow
    $Logger = Get-Logger
    $Logger.Info("No TableScripts found in ChangeContent in: $ZipPath")
  }
}
catch {
  $Logger = Get-Logger
  $Logger.Info("ERROR: Export failed!")
  $Logger.Info($_.Exception.Message)
  Write-Host ""
  Write-Host "ERROR: Export failed!" -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  if ($_.ScriptStackTrace) {
    $Logger = Get-Logger
    $Logger.Info("Stack Trace:")
    $Logger.Info($_.ScriptStackTrace)
    Write-Host ""
    Write-Host "Stack Trace:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
  }
  throw
}
#endregion
}

# Export module members
Export-ModuleMember -Function @(
  'TableScripts_Main_PsModule'
)
