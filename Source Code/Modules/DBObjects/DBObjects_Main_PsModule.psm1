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
  [string]$DMDll,

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
Import-Module (Join-Path $scriptDir "DBObjects_XmlParser.psm1") -Force
Import-Module (Join-Path $commonDir "PsModuleLogin.psm1") -Force
Import-Module (Join-Path $scriptDir "DBObjects_XmlExporter.psm1") -Force
Import-Module (Join-Path $scriptDir "DBObjects_CsvExporter.psm1") -Force
Import-Module (Join-Path $scriptDir "DBObjects_FilterColumnsPsModule.psm1") -Force
#endregion

#region Main Execution
try {
  $Logger = Get-Logger
  $Logger.Info("OIM DbObjects Export Tool")
  $Logger.Info("Mode: $(if($CSVMode){'CSV (Separate XML + CSV per table)'}else{'Normal (Single XML with data)'})")

  # Step 1: Parse input XML
  Write-Host "  [1/5] Parsing input XML: $ZipPath"
  $Logger.Info("Parsing input XML")
  $dbObjects = Get-AllDbObjectsFromChangeContent -ZipPath $ZipPath -IncludeEmptyValues:$IncludeEmptyValues

  if (-not $dbObjects -or $dbObjects.Count -eq 0) {
    Write-Host "  No DbObjects found in: $ZipPath" -ForegroundColor Yellow
    $Logger = Get-Logger
    $Logger.Info("No embedded DbObjects found in ChangeContent columns.")
    return
  }

  $uniqueTables = $dbObjects.TableName | Where-Object { $_ } | Sort-Object -Unique
  Write-Host "  Found $($dbObjects.Count) DbObject(s) across $($uniqueTables.Count) table(s): $($uniqueTables -join ', ')"
  $Logger = Get-Logger
  $Logger.Info("Found $($dbObjects.Count) DbObject(s) across $($uniqueTables.Count) table(s): $($uniqueTables -join ', ')")

  # Report mode: if any stale abort was triggered during parsing, print report and exit
  if ($global:XDateCheck_StaleAbortTriggered) {
    Write-Host "  [REPORT MODE] Stale object abort triggered - no files will be written." -ForegroundColor Yellow
    $Logger.Info("[REPORT MODE] Stale object abort triggered - no files will be written.")
    foreach ($tbl in $uniqueTables) {
      $tblObjs = @($dbObjects | Where-Object { $_.TableName -eq $tbl })
      Write-Host "    Table: $tbl ($($tblObjs.Count) object(s))" -ForegroundColor Cyan
      foreach ($o in $tblObjs) {
        $pkArr = @($o.PkName); $pvArr = @($o.PkValue)
        $pkStr = (0..([Math]::Min($pkArr.Count, $pvArr.Count) - 1) | ForEach-Object { "$($pkArr[$_]) = $($pvArr[$_])" }) -join ", "
        Write-Host "      - $pkStr" -ForegroundColor Gray
      }
    }
    return
  }

  # Step 2: Login to API
  Write-Host "  [2/5] Opening session with DMConfigDir: $DMConfigDir"
  $Logger.Info("Opening session with DMConfigDir: $DMConfigDir")
  $session = Connect-OimPSModule -DMConfigDir $DMConfigDir -DMDll $DMDll -OutPath $OutPath -DMPassword $DMPassword
  $Logger = Get-Logger
  $Logger.Info("Authentication successful")

  # Step 2.5: Discover FK metadata and enrich parsed objects
  Write-Host "  [2.5/5] Discovering FK metadata for tables: $($uniqueTables -join ', ')" -ForegroundColor Cyan
  $Logger.Info("Discovering FK metadata for tables: $($uniqueTables -join ', ')")
  $fkMetaByTable = Get-ForeignKeyMetadataPsModule -Session $session -Tables $uniqueTables
  $dbObjects = Enrich-DbObjectsWithFkMetadata -DbObjects $dbObjects -FkMetaByTable $fkMetaByTable
  $Logger.Info("FK metadata enrichment completed")

  # Step 2.6: Sort objects by SortOrder from QBMTaggedChange wrapper
  Write-Host "  [2.6/5] Sorting objects by SortOrder..." -ForegroundColor Cyan
  $Logger.Info("Sorting objects by SortOrder")
  $dbObjects = Sort-DbObjectsBySortOrder -DbObjects $dbObjects
  $Logger.Info("SortOrder sort completed")

  # Step 3: Get column permissions
  Write-Host "  [3/5] Retrieving column permissions for tables: $($uniqueTables -join ', ')"
  $Logger.Info("Retrieving column permissions for tables: $($uniqueTables -join ', ')")
  $allowedByTable = Get-ColumnPermissionsPsModule -Session $session -Tables $uniqueTables
  Write-Host "  Retrieved permissions for $($allowedByTable.Count) table(s)"
  $Logger.Info("Retrieved permissions for $($allowedByTable.Count) table(s)")

  # Step 4: Filter columns
  Write-Host "  [4/5] Filtering columns based on permissions"
  $Logger.Info("Filtering columns based on permissions")
  $dbObjectsFiltered = Filter-DbObjectsByAllowedColumnsPsModule -DbObjects $dbObjects -AllowedColumnsByTable $allowedByTable
  $totalColumns = ($dbObjectsFiltered | ForEach-Object { $_.Columns.Count } | Measure-Object -Sum).Sum
  Write-Host "  Retained $totalColumns allowed column(s) across all objects"
  $Logger.Info("Retained $totalColumns allowed column(s) across all objects")

  # Step 5: Export
  $outpathfolder = Join-Path $OutPath "DBObjects"
  if (-not (Test-Path $outpathfolder)) {
    New-Item -Path $outpathfolder -ItemType Directory -Force | Out-Null
  }
  Write-Host "  [5/5] Exporting to: $outpathfolder"
  $Logger.Info("Exporting to: $outpathfolder")

  if ($CSVMode) {
    Export-ToCsvMode -DbObjects $dbObjectsFiltered -OutPath $outpathfolder -PreviewXml:$PreviewXml -TableNameMapCsvPath $TableNameMapCSV | Out-Null
  }
  else {
    Export-ToNormalXml -DbObjects $dbObjectsFiltered -OutPath $outpathfolder -PreviewXml:$PreviewXml | Out-Null
  }

  $Logger.Info("Export completed successfully!")
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
  'DBObjects_Main_PsModule'
)
