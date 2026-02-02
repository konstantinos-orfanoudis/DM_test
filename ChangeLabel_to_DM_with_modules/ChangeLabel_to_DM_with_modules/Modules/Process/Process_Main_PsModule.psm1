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

  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$DMDll
)

#region Module Imports
$scriptDir = $PSScriptRoot
$parent = Split-Path -Parent $PSScriptRoot

# Import all required modules
Import-Module (Join-Path $scriptDir "Export-Process.psm1") -Force
Import-Module (Join-Path $scriptDir "Process_XmlParser.psm1") -Force
Import-Module (Join-Path $parent "PsModuleLogin.psm1") -Force
#endregion

#region Main Execution
try {
  Write-Host "OIM Process Export Tool" -ForegroundColor Cyan
  Write-Host ""

  # Step 1: Parse input XML
  Write-Host "[1/3] Parsing input XML: $ZipPath"
  
  # Step 2: Login to API
  Write-Host "[2/3] Opening session with DMConfigDir: $DMConfigDir"
  $session = Connect-OimPSModule -ConfigDir $DMConfigDir -DMDll $DMDll
  
  # Get processes from the XML
  $processes = GetAllProcessFromChangeLabel -Path $ZipPath -Session $session
  
  Write-Host "Found $($processes.Count) process(es)" -ForegroundColor Cyan
  Write-Host ""

  # Step 3: Export Process
  if ($processes.Count -gt 0) {
    Write-Host "[3/3] Exporting to: $OutPath"
    
    foreach($pr in $processes){
      $ProcessName = $pr.Name
      $TableName = $pr.TableName
      $ProcessOutPath = Join-Path $OutPath "$ProcessName.xml"
      
      Write-Host "  Exporting process: $ProcessName ($TableName)" -ForegroundColor Gray
      Export-Process -Name $ProcessName -TableName $TableName -OutFilePath $ProcessOutPath
    }
    
    Write-Host ""
    Write-Host "Export completed successfully!" -ForegroundColor Green
  }
  else {
    Write-Host "No processes found in: $ZipPath" -ForegroundColor Yellow
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

# Export module members
Export-ModuleMember -Function @(
  'Process_Main_PsModule'
)