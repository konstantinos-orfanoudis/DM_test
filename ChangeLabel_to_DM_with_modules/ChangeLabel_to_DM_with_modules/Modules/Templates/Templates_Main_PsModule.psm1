

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

.PARAMETER ApiBaseUrl
  Base URL for the OIM API. Default: http://localhost:8182

.PARAMETER ApiModule
  OIM module name for authentication. Default: SupportPlus

.PARAMETER ApiUser
  Username for API authentication. Default: viadmin

.PARAMETER ApiPassword
  Password for API authentication. Default: P@ssword.123

.EXAMPLE
  .\Main.ps1 -Path "C:\Input\tagdata.xml" -OutPath "C:\Output"



.EXAMPLE
  .\Main.ps1 -Path "C:\Input\tagdata.xml" -OutPath "C:\Output" -CSVMode -PreviewXml
#>

function Templates_Main_PsModule{
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [ValidateNotNullOrEmpty()]
  [string]$Path,

  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$OutPath,

  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$ConfigDir,

  [Parameter(Mandatory = $true)]
  [string]$LogPath,
  
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$DMDll
)

    #region Module Imports

    $scriptDir = $PSScriptRoot
    $parent = Split-Path -Parent $PSScriptRoot
    # Import all required modules
    Import-Module (Join-Path $scriptDir "Templates_XmlParser.psm1") -Force
    Import-Module (Join-Path $parent "PsModuleLogin.psm1") -Force
    Import-Module (Join-Path $scriptDir "Templates_Exporter_PsModule.psm1") -Force

    #endregion

    #region Main Execution
    # Step 1: Parse input XML
    Write-Host "[1/5] Parsing input XML: $Path"
    $templates = Get-TemplatesFromChangeContent -Path $Path
    Write-Host "Templates found: $($templates.Count)" -ForegroundColor Cyan

    if ($templates.Count -gt 0) {
        # Step 2: Login to API
        
        $session = Connect-OimPSModule -ConfigDir $ConfigDir -DMDll $DMDll
        Write-Host "Authentication successful"
        Write-Host ""
        $outDirTemplates = Join-Path -Path $OutPath -ChildPath "Templates"
        Write-TemplatesAsVbNetFiles -Templates $templates -OutDir $outDirTemplates
    } else {
      Write-Host "No templates found in ChangeContent in: $Path" -ForegroundColor Yellow
    }
}

# Export module members
Export-ModuleMember -Function @(
  'Templates_Main_PsModule'
)