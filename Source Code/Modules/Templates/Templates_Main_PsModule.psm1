<#
.SYNOPSIS
  Main script to export OIM Templates from TagData XML files.

.DESCRIPTION
  Orchestrates the extraction of Templates from OIM Transport XML files.

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
  Templates_Main_PsModule -Path "C:\Input\tagdata.xml" -OutPath "C:\Output" -ConfigDir "C:\Config" -DMDll "C:\DM.dll"
#>

function Templates_Main_PsModule{
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
  [string]$DMPassword = ""
)

#region Module Imports
$scriptDir = $PSScriptRoot
$modulesDir = Split-Path -Parent $PSScriptRoot
$commonDir = Join-Path $modulesDir "Common"

# Import all required modules
Import-Module (Join-Path $scriptDir "Templates_XmlParser.psm1") -Force
Import-Module (Join-Path $commonDir "PsModuleLogin.psm1") -Force
Import-Module (Join-Path $scriptDir "Templates_Exporter_PsModule.psm1") -Force
#endregion

#region Main Execution
$Logger = Get-Logger

try {
  $Logger.info("OIM Templates Export Tool")
  Write-Host "OIM Templates Export Tool" -ForegroundColor Cyan
  Write-Host ""

  # Step 1: Parse input XML
  $Logger.Info("Parsing input XML: $ZipPath")
  Write-Host "[1/3] Parsing input XML: $ZipPath"
  $templates = Get-TemplatesFromChangeContent -ZipPath $ZipPath
  Write-Host "Found $($templates.Count) template(s)" -ForegroundColor Cyan
  $Logger.Info("Found $($templates.Count) template(s)")

  if ($templates.Count -gt 0) {
    # Step 2: Login to API
    $Logger.Info("Opening session with DMConfigDir")
    Write-Host "[2/3] Opening session with DMConfigDir: $DMConfigDir"
    $session = Connect-OimPSModule -DMConfigDir $DMConfigDir -DMDll $DMDll -OutPath $OutPath -DMPassword $DMPassword
    Write-Host "Authentication successful"
    $Logger = Get-Logger
    $Logger.Info("Authentication successful")
    Write-Host ""
    
    # Step 3: Export Templates
    Write-Host "[3/3] Exporting to: $OutPath"
    $Logger.Info("Exporting to: $OutPath")
    $outDirTemplates = Join-Path -Path $OutPath -ChildPath "Templates"
    Write-TemplatesAsVbNetFiles -Templates $templates -OutDir $outDirTemplates
    
    Write-Host ""
    Write-Host "Export completed successfully!" -ForegroundColor Green
    $Logger.Info("Export completed successfully!")
  } 
  else {
    $Logger = Get-Logger
    $Logger.Info("No templates found in ChangeContent in: $ZipPath")
    Write-Host "No templates found in ChangeContent in: $ZipPath" -ForegroundColor Yellow
  }
}
catch {
  $Logger.Info("ERROR: Export failed!")
  Write-Host ""
  Write-Host "ERROR: Export failed!" -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  if ($_.ScriptStackTrace) {
    Write-Host ""
    Write-Host "Stack Trace:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
    $Logger.Info("Stack Trace:")
  }
  throw
}
#endregion
}

# Export module members
Export-ModuleMember -Function @(
  'Templates_Main_PsModule'
)
