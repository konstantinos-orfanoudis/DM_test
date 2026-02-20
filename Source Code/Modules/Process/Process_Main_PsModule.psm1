<#
.SYNOPSIS
  Main script to export OIM Processes from TagData XML files.

.DESCRIPTION
  Orchestrates the extraction of Process/JobChain data from OIM Transport XML files.

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
  Process_Main_PsModule -Path "C:\Input\tagdata.xml" -OutPath "C:\Output" -ConfigDir "C:\Config" -DMDll "C:\DM.dll"
#>

function Process_Main_PsModule{
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

  [Parameter(Mandatory = $false)]
  [switch]$CSVMode,

  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$DMDll,
  
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
Import-Module (Join-Path $scriptDir "Export-Process.psm1") -Force
Import-Module (Join-Path $scriptDir "Process_XmlParser.psm1") -Force
Import-Module (Join-Path $commonDir "PsModuleLogin.psm1") -Force
#endregion

#region Main Execution
try {
  $Logger = Get-Logger
  $Logger.Info("OIM Process Export Tool")

  # Step 1: Login to API (required before parsing - session used during XML parse)
  $Logger.Info("Opening session with DMConfigDir: $DMConfigDir")
  $session = Connect-OimPSModule -DMConfigDir $DMConfigDir -DMDll $DMDll -OutPath $OutPath -DMPassword $DMPassword

  # Step 2: Parse input XML (requires live session for DB lookups)
  $Logger.Info("Parsing input XML: $ZipPath")
  $processes = GetAllProcessFromChangeLabel -ZipPath $ZipPath -Session $session
  $Logger = Get-Logger
  $Logger.Info("Found $($processes.Count) process(es)")
  Write-Host "  Found $($processes.Count) process(es)" -ForegroundColor Cyan

  # Report mode: if any stale abort was triggered during parsing, print report and exit
  if ($global:XDateCheck_StaleAbortTriggered) {
    Write-Host "  [REPORT MODE] Stale object abort triggered - no files will be written." -ForegroundColor Yellow
    $Logger.Info("[REPORT MODE] Stale object abort triggered - no files will be written.")
    foreach ($p in $processes) {
      Write-Host "    - $($p.Name) ($($p.TableName))" -ForegroundColor Gray
    }
    return
  }

  # Step 3: Export Processes
  if ($processes.Count -gt 0) {
    $outpathfolder = Join-Path $OutPath "Processes"
    if (-not (Test-Path $outpathfolder)) {
      New-Item -Path $outpathfolder -ItemType Directory -Force | Out-Null
    }
    Write-Host "  Exporting to: $outpathfolder" -ForegroundColor Gray
    $Logger.Info("Exporting to: $outpathfolder")

    $counter = 0
    foreach ($pr in $processes) {
      $ProcessName = $pr.Name
      $TableName   = $pr.TableName
      $ProcessOutPath = Join-Path $outpathfolder ('{0:D3}-{1}.xml' -f $counter, $ProcessName)
      Write-Host "    $ProcessName ($TableName)" -ForegroundColor Gray
      $Logger.Info("Exporting process: $ProcessName ($TableName)")
      Export-Process -Name $ProcessName -TableName $TableName -OutFilePath $ProcessOutPath
      $counter++
    }
    $Logger = Get-Logger
    $Logger.Info("Export completed successfully!")
  }
  else {
    $Logger = Get-Logger
    Write-Host "  No processes found in: $ZipPath" -ForegroundColor Yellow
    $Logger.Info("No processes found in: $ZipPath")
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
  'Process_Main_PsModule'
)