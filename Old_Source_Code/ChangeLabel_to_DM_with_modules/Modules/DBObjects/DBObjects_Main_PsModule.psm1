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

.PARAMETER ConfigDir
  Configuration directory for OIM connection.

.PARAMETER LogPath
  Optional log file path. If not provided, defaults to OutPath\Logs\export.log

.PARAMETER IncludeEmptyValues
  If set, includes columns even when their value is empty. Default: off.

.PARAMETER PreviewXml
  If set, prints the generated XML to the console.

.PARAMETER CSVMode
  If set, generates schema-only XML files with @placeholders@ and separate CSV files per table.

.PARAMETER DMDll
  Path to the Deployment Manager DLL.

.EXAMPLE
  DBObjects_Main_PsModule -Path "C:\Input\tagdata.xml" -OutPath "C:\Output" -ConfigDir "C:\Config" -DMDll "C:\DM.dll"

.EXAMPLE
  DBObjects_Main_PsModule -Path "C:\Input\tagdata.xml" -OutPath "C:\Output" -ConfigDir "C:\Config" -DMDll "C:\DM.dll" -CSVMode

.EXAMPLE
  DBObjects_Main_PsModule -Path "C:\Input\tagdata.xml" -OutPath "C:\Output" -ConfigDir "C:\Config" -DMDll "C:\DM.dll" -CSVMode -PreviewXml
#>

function DBObjects_Main_PsModule{
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
  [switch]$IncludeEmptyValues,

  [Parameter(Mandatory = $false)]
  [switch]$PreviewXml,

  [Parameter(Mandatory = $false)]
  [switch]$CSVMode,
   
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$DMDll
)

#region Module Imports
$scriptDir = $PSScriptRoot
$parent = Split-Path -Parent $PSScriptRoot

# Import all required modules
Import-Module (Join-Path $scriptDir "DBObjects_XmlParser.psm1") -Force
Import-Module (Join-Path $parent "PsModuleLogin.psm1") -Force
Import-Module (Join-Path $scriptDir "DBObjects_XmlExporter.psm1") -Force
Import-Module (Join-Path $scriptDir "DBObjects_CsvExporter.psm1") -Force
Import-Module (Join-Path $scriptDir "DBObjects_FilterColumnsPsModule.psm1") -Force
#endregion

#region Main Execution
try {
  Write-Host "OIM DbObjects Export Tool" -ForegroundColor Cyan
  Write-Host "Mode: $(if($CSVMode){'CSV (Separate XML + CSV per table)'}else{'Normal (Single XML with data)'})"
  Write-Host ""

  # Step 1: Parse input XML
  Write-Host "[1/5] Parsing input XML: $ZipPath"
  $dbObjects = Get-AllDbObjectsFromChangeContent -ZipPath $ZipPath -IncludeEmptyValues:$IncludeEmptyValues

  if (-not $dbObjects -or $dbObjects.Count -eq 0) {
    Write-Host "No embedded DbObjects found in ChangeContent columns." -ForegroundColor Yellow
    return
  }

  $uniqueTables = $dbObjects.TableName | Where-Object { $_ } | Sort-Object -Unique
  Write-Host "Found $($dbObjects.Count) DbObject(s) across $($uniqueTables.Count) table(s): $($uniqueTables -join ', ')"
  Write-Host ""

  # Step 2: Login to API
  Write-Host "[2/5] Opening session with DMConfigDir: $DMConfigDir"
  $session = Connect-OimPSModule -ConfigDir $DMConfigDir -DMDll $DMDll
  Write-Host "Authentication successful"
  Write-Host ""

  # Step 3: Get column permissions
  Write-Host "[3/5] Retrieving column permissions for tables: $($uniqueTables -join ', ')"
  $allowedByTable = Get-ColumnPermissionsPsModule -Session $session -Tables $uniqueTables
  Write-Host "Retrieved permissions for $($allowedByTable.Count) table(s)"
  Write-Host ""

  # Step 4: Filter columns
  Write-Host "[4/5] Filtering columns based on permissions"
  $dbObjectsFiltered = Filter-DbObjectsByAllowedColumnsPsModule -DbObjects $dbObjects -AllowedColumnsByTable $allowedByTable
  $totalColumns = ($dbObjectsFiltered | ForEach-Object { $_.Columns.Count } | Measure-Object -Sum).Sum
  Write-Host "Retained $totalColumns allowed column(s) across all objects"
  Write-Host ""

  # Step 5: Export
  Write-Host "[5/5] Exporting to: $OutPath"
  
  if ($CSVMode) {
    Export-ToCsvMode -DbObjects $dbObjectsFiltered -OutPath $OutPath -PreviewXml:$PreviewXml | Out-Null
  }
  else {
    Export-ToNormalXml -DbObjects $dbObjectsFiltered -OutPath $OutPath -PreviewXml:$PreviewXml | Out-Null
  }
  
  Write-Host ""
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
  'DBObjects_Main_PsModule'
)
