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
  [string]$DMPassword = ""
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
  $Logger.info("OIM Process Export Tool")
  Write-Host "OIM Process Export Tool" -ForegroundColor Cyan
  Write-Host ""

  # Step 1: Parse input XML
  Write-Host "[1/3] Parsing input XML: $ZipPath"
  $Logger.info("Parsing input XML: $ZipPath")
  
  # Step 2: Login to API
  Write-Host "[2/3] Opening session with DMConfigDir: $DMConfigDir"
  $Logger.info("Opening session with DMConfigDir: $DMConfigDir")
  $session = Connect-OimPSModule -DMConfigDir $DMConfigDir -DMDll $DMDll -OutPath $OutPath -DMPassword $DMPassword
  
  # Get processes from the XML
  $processes = GetAllProcessFromChangeLabel -ZipPath $ZipPath -Session $session
  $Logger = Get-Logger
  $Logger.info("Found $($processes.Count) process(es)")
  Write-Host "Found $($processes.Count) process(es)" -ForegroundColor Cyan
  Write-Host ""

  # Step 3: Export Process
  if ($processes.Count -gt 0) {
    
    $counter = 000
    foreach($pr in $processes){
      $ProcessName = $pr.Name
      $TableName = $pr.TableName
      $outpathfolder = "$OutPath"+"\Processes"  
      if (-not (Test-Path $outpathfolder)) {
          New-Item -Path $outpathfolder -ItemType Directory -Force | Out-Null
      }
      $ProcessOutPath = ('{0:D3}-{1}' -f ($counter), $ProcessName) 
      $ProcessOutPath = Join-Path  $outpathfolder "$ProcessOutPath.xml"
         
      Write-Host "  Exporting process: $ProcessName ($TableName)" -ForegroundColor Gray
      $Logger.info("Exporting process: $ProcessName ($TableName)")
      Export-Process -Name $ProcessName -TableName $TableName -OutFilePath $ProcessOutPath
      
      $counter++ 
    }
    $Logger = Get-Logger
    $Logger.info("Exporting to: $outpathfolder")
    Write-Host "[3/3] Exporting to: $outpathfolder"
    Write-Host ""
    Write-Host "Export completed successfully!" -ForegroundColor Green
    $Logger.info("Export completed successfully!")
  }
  else {
    $Logger = Get-Logger
    $Logger.info("No processes found in: $ZipPath")
    Write-Host "No processes found in: $ZipPath" -ForegroundColor Yellow
  }
}
catch {
  $Logger = Get-Logger
  $Logger.info("ERROR: Export failed!")
  $Logger.info($_.Exception.Message)
  Write-Host ""
  Write-Host "ERROR: Export failed!" -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  if ($_.ScriptStackTrace) {
    $Logger = Get-Logger
    $Logger.info("Stack Trace:")
    $Logger.info($_.ScriptStackTrace)
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
  'Process_Main_PsModule'
)