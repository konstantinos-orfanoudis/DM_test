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

.PARAMETER IncludeEmptyValues
  If set, includes columns even when their value is empty. Default: off.

.PARAMETER PreviewXml
  If set, prints the generated XML to the console.

.PARAMETER CSVMode
  If set, generates schema-only XML files with @placeholders@ and separate CSV files per table.

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
  .\Main.ps1 -Path "C:\Input\tagdata.xml" -OutPath "C:\Output" -CSVMode

.EXAMPLE
  .\Main.ps1 -Path "C:\Input\tagdata.xml" -OutPath "C:\Output" -CSVMode -PreviewXml
#>

function DBObjects_Main{
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [ValidateNotNullOrEmpty()]
  [string]$Path,

  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$OutPath,

  [Parameter(Mandatory = $false)]
  [switch]$IncludeEmptyValues,

  [Parameter(Mandatory = $false)]
  [switch]$PreviewXml,

  [Parameter(Mandatory = $false)]
  [switch]$CSVMode,

  [Parameter(Mandatory = $false)]
  [string]$ApiBaseUrl = "http://localhost:8182",

  [Parameter(Mandatory = $false)]
  [string]$ApiModule = "SupportPlus",

  [Parameter(Mandatory = $false)]
  [string]$ApiUser = "viadmin",

  [Parameter(Mandatory = $false)]
  [string]$ApiPassword = "P@ssword.123"
)

#region Module Imports

$scriptDir = $PSScriptRoot
$parent = Split-Path -Parent $PSScriptRoot
# Import all required modules
Import-Module (Join-Path $scriptDir "DBObjects_XmlParser.psm1") -Force
Import-Module (Join-Path $parent "ApiLogin.psm1") -Force
Import-Module (Join-Path $scriptDir "DBObjects_XmlExporter.psm1") -Force
Import-Module (Join-Path $scriptDir "DBObjects_CsvExporter.psm1") -Force
Import-Module (Join-Path $scriptDir "DBObjects_FilterColumns.psm1") -Force

#endregion

#region Main Execution

try {
  Write-Host "OIM DbObjects Export Tool" -ForegroundColor Cyan
  Write-Host "Mode: $(if($CSVMode){'CSV (Separate XML + CSV per table)'}else{'Normal (Single XML with data)'})"
  Write-Host ""

  # Step 1: Parse input XML
  Write-Host "[1/5] Parsing input XML: $Path"
  $dbObjects = Get-AllDbObjectsFromChangeContent -Path $Path -IncludeEmptyValues:$IncludeEmptyValues

  if (-not $dbObjects -or $dbObjects.Count -eq 0) {
    Write-Host "No embedded DbObjects found in ChangeContent columns." -ForegroundColor Yellow
    return
  }

  $uniqueTables = $dbObjects.TableName | Where-Object { $_ } | Sort-Object -Unique
  Write-Host "Found $($dbObjects.Count) DbObject(s) across $($uniqueTables.Count) table(s): $($uniqueTables -join ', ')"
  Write-Host ""

  # Step 2: Login to API
  Write-Host "[2/5] Authenticating with API: $ApiBaseUrl"
  $session = Connect-OimApi -BaseUrl $ApiBaseUrl -Module $ApiModule -User $ApiUser -Password $ApiPassword
  Write-Host "Authentication successful"
  Write-Host ""

  # Step 3: Get column permissions
  Write-Host "[3/5] Retrieving column permissions for tables: $($uniqueTables -join ', ')"
  $allowedByTable = Get-ColumnPermissions -BaseUrl $ApiBaseUrl -Session $session -Tables $uniqueTables
  Write-Host "Retrieved permissions for $($allowedByTable.Count) table(s)"
  Write-Host ""

  # Step 4: Filter columns
  Write-Host "[4/5] Filtering columns based on permissions"
  $dbObjectsFiltered = Filter-DbObjectsByAllowedColumns -DbObjects $dbObjects -AllowedColumnsByTable $allowedByTable
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
  'DBObjects_Main'
)
