<#
.SYNOPSIS
  Main script to export OIM Scripts from TagData XML files.

.DESCRIPTION
  Orchestrates the extraction of Scripts from OIM Transport XML files.
  Extracts script data directly from XML - no database connection required.

.PARAMETER ZipPath
  Path to the input XML file (e.g., TagData.xml extracted from transport ZIP).

.PARAMETER OutPath
  Output directory path where all files will be exported.

.PARAMETER DMConfigDir
  Configuration directory for OIM connection (not used for scripts).

.PARAMETER LogPath
  Optional log file path.

.PARAMETER DMDll
  Path to the Deployment Manager DLL (not used for scripts).

.EXAMPLE
  Scripts_Main_PsModule -ZipPath "C:\Input\tagdata.xml" -OutPath "C:\Output"
#>

function Scripts_Main_PsModule{
param(
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$ZipPath,

  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$OutPath,

  [Parameter(Mandatory = $false)]
  [string]$DMConfigDir = "",

  [Parameter(Mandatory = $false)]
  [string]$LogPath = "",

  [Parameter(Mandatory = $false)]
  [string]$DMDll = ""
)

#region Module Imports
$scriptDir = $PSScriptRoot

# Import parser and exporter
Import-Module (Join-Path $scriptDir "Scripts_XmlParser.psm1") -Force
Import-Module (Join-Path $scriptDir "Scripts_Exporter_PsModule.psm1") -Force
#endregion

#region Main Execution
try {
  Write-Host "OIM Scripts Export Tool" -ForegroundColor Cyan
  Write-Host ""

  # Step 1: Parse input XML - extracts script data from ChangeContent
  Write-Host "[1/3] Parsing input XML: $ZipPath"
  $scripts = Get-ScriptsFromChangeLabel -Path $ZipPath 

  Write-Host "Found $($scripts.Count) script(s)" -ForegroundColor Cyan

  if ($scripts.Count -gt 0) {
    # Display what we found
    foreach ($s in $scripts) {
      Write-Host "  - $($s.ScriptName) (UID: $($s.UID.Substring(0,15))...)" -ForegroundColor Gray
    }
    Write-Host ""

    # Step 2: No database connection needed - we have all data from XML!
    Write-Host "[2/3] Script data extracted from XML (no database queries needed)" -ForegroundColor Green
    Write-Host ""
    
    # Step 3: Export Scripts
    Write-Host "[3/3] Exporting to: $OutPath"
    $outDirScripts = Join-Path -Path $OutPath -ChildPath "Scripts"
    Write-ScriptsAsVbNetFiles -Scripts $scripts -OutDir $outDirScripts
    
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

# Export module members
Export-ModuleMember -Function @(
  'Scripts_Main_PsModule'
)