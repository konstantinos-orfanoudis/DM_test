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



.EXAMPLE
  .\Main.ps1 -Path "C:\Input\tagdata.xml" -OutPath "C:\Output"
#>

function Scripts_Main_PsModule{
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
Import-Module (Join-Path $scriptDir "Scripts_XmlParser.psm1") -Force
Import-Module (Join-Path $parent "PsModuleLogin.psm1") -Force
Import-Module (Join-Path $scriptDir "Scripts_Exporter_PsModule.psm1") -Force

#endregion

#region Main Execution


  Write-Host "OIM Scripts Export Tool" -ForegroundColor Cyan
  Write-Host ""

  # Step 1: Parse input XML
  Write-Host "[1/5] Parsing input XML: $Path"
  $scripts = Get-ScriptKeysFromChangeLabel -Path $Path 

  Write-Host "scripts found: $($scripts.Count)" -ForegroundColor Cyan

    if ($scripts.Count -gt 0) {
        # Step 2: Login to API
        
        $session = Connect-OimPSModule -ConfigDir $ConfigDir -DMDll $DMDll
        Write-Host "Authentication successful"
        Write-Host ""
        $outDirScripts = Join-Path -Path $OutPath -ChildPath "Scripts"
        Write-ScriptsAsVbNetFiles -Scripts $scripts -OutDir $outDirScripts
    } else {
      Write-Host "No scripts found in ChangeContent in: $Path" -ForegroundColor Yellow
    }


#endregion
}

# Export module members
Export-ModuleMember -Function @(
  'Scripts_Main_PsModule'
)
