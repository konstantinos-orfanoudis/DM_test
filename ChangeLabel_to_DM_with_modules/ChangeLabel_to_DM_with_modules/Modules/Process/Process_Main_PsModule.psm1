<#
.SYNOPSIS
  Main script to export OIM DbObjects from TagData XML files.

.DESCRIPTION
  Orchestrates the extraction of DbObjects from OIM Transport XML files,
  applies column-level permissions, and exports to either normal XML format
  or CSV mode (separate XML schema + CSV data files per table).

.PARAMETER Path
  Path to the input XML file (e.g., Transport TagData.xml).

.PARAMETER OutPath
  Output directory path where all files will be exported.
#>

function Process_Main_PsModule{
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [ValidateNotNullOrEmpty()]
  [string]$Path,

  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$OutPath,

   [Parameter(Mandatory = $true)]
    [string]$ConfigDir,

    [Parameter(Mandatory = $true)]
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
  

  
  

  

  # Step 2: Login to API
  Write-Host "[2/3] Open Session: $Path"
  $session = Connect-OimPSModule -ConfigDir $ConfigDir -DMDll $DMDll

  $processes = GetAllProcessFromChangeLabel -Path $Path -Session $session
  Write-Host "Authentication successful"
  Write-Host ""

  # Step 3: Export Process
  Write-Host "[3/3] Exporting to: $OutPath"
  Write-Host $processes

  foreach($pr in $processes){
    $ProcessName = $pr.Name
    $TableName = $pr.TableName
    $OutPath = $Outpath + "\$ProcessName.xml"
    Export-Process -Name $ProcessName -TableName $TableName -OutFilePath $OutPath
  }
  
  Write-Host "Export completed successfully!" -ForegroundColor Green
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
