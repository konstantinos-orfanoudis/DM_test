<#
.SYNOPSIS
  Main script.

.DESCRIPTION
  Orchestrates the extraction of all the files.

.PARAMETER ZipPath
  Path to the input ZIP file containing TagTransport data.

.PARAMETER DMConfigDir
  Configuration directory path.

.PARAMETER OutPath
  Output directory path where all files will be exported.

.PARAMETER LogPath
  Log file path.

.PARAMETER IncludeEmptyValues
  If set, includes columns even when their value is empty. Default: off.

.PARAMETER PreviewXml
  If set, prints the generated XML to the console.

.PARAMETER CSVMode
  If set, generates schema-only XML files with @placeholders@ and separate CSV files per table.

.PARAMETER DMDll
  Path to the Deployment Manager DLL.

.EXAMPLE
  .\MainPsModule.ps1 -ZipPath "C:\Input\export.zip" -OutPath "C:\Output" -ConfigDir "C:\Config" -DMDll "C:\DM.dll"
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$ZipPath,
  [string]$DMConfigDir,
  [string]$OutPath,
  [string]$LogPath,
  [switch]$IncludeEmptyValues,
  [switch]$PreviewXml,
  [switch]$CSVMode,
  [string]$DMDll
)

# --- Script Initialization ---
$scriptDir = $PSScriptRoot

#region Module Imports
$modulesDir = Join-Path $scriptDir "Modules"
$commonDir = Join-Path $modulesDir "Common"

Import-Module (Join-Path $modulesDir "DBObjects/DBObjects_Main_PsModule.psm1") -Force
Import-Module (Join-Path $modulesDir "Process/Process_Main_PsModule.psm1") -Force
Import-Module (Join-Path $modulesDir "Templates/Templates_Main_PsModule.psm1") -Force
Import-Module (Join-Path $modulesDir "Scripts/Scripts_Main_PsModule.psm1") -Force
Import-Module (Join-Path $modulesDir "TableScripts/TableScripts_Main_PsModule.psm1") -Force
Import-Module (Join-Path $modulesDir "FormatScripts/FormatScripts_Main_PsModule.psm1") -Force
Import-Module (Join-Path $commonDir "ExtractXMLFromZip.psm1") -Force
Import-Module (Join-Path $scriptDir "NLogger.psm1") -Force
Import-Module (Join-Path $scriptDir "InputValidator.psm1") -Force
#endregion


$Logger = Get-Logger 



#region Main Execution
try {
  
  Write-Host "=== OIM Export Tool ===" -ForegroundColor Cyan
  Write-Host ""

  # Step 1: Extract XML files from ZIP
  $Logger.Info("Extracting XML files from ZIP")
  Write-Host "[1/3] Extracting XML files from ZIP: $ZipPath" -ForegroundColor Yellow
  $xmlFiles = Resolve-TagDataXmlFromZip -ZipPath $ZipPath
  $Logger.Info("Extracted $($xmlFiles.Count) XML file(s)")
  Write-Host "Extracted $($xmlFiles.Count) XML file(s)" -ForegroundColor Green
  Write-Host ""

  # Step 2: Validate and merge configuration
  Write-Host "[2/3] Validating configuration..." -ForegroundColor Yellow
  # Build parameter hashtable - only include parameters that were actually passed or have values
  $validatorParams = @{}
  
  if ($PSBoundParameters.ContainsKey('DMConfigDir')) {
    $validatorParams['DMConfigDir'] = $DMConfigDir
  }
  if ($PSBoundParameters.ContainsKey('OutPath')) {
    $validatorParams['OutPath'] = $OutPath
  }
  if ($PSBoundParameters.ContainsKey('LogPath')) {
    $validatorParams['LogPath'] = $LogPath
  }
  if ($PSBoundParameters.ContainsKey('DMDll')) {
    $validatorParams['DMDll'] = $DMDll
  }
  if ($PSBoundParameters.ContainsKey('IncludeEmptyValues')) {
    $validatorParams['IncludeEmptyValues'] = $IncludeEmptyValues
  }
  if ($PSBoundParameters.ContainsKey('PreviewXml')) {
    $validatorParams['PreviewXml'] = $PreviewXml
  }
  if ($PSBoundParameters.ContainsKey('CSVMode')) {
    $validatorParams['CSVMode'] = $CSVMode
  }
  
  $config = InputValidator @validatorParams
  
  Write-Host "Configuration loaded:" -ForegroundColor Cyan
  Write-Host "  DMConfigDir:        $($config.DMConfigDir)" -ForegroundColor Gray
  Write-Host "  OutPath:            $($config.OutPath)" -ForegroundColor Gray
  Write-Host "  LogPath:            $($config.LogPath)" -ForegroundColor Gray
  Write-Host "  DMDll:              $($config.DMDll)" -ForegroundColor Gray
  Write-Host "  IncludeEmptyValues: $($config.IncludeEmptyValues)" -ForegroundColor Gray
  Write-Host "  PreviewXml:         $($config.PreviewXml)" -ForegroundColor Gray
  Write-Host "  CSVMode:            $($config.CSVMode)" -ForegroundColor Gray
  Write-Host ""

  # Step 3: Process each XML file
  $Logger.Info("Processing XML files...")
  Write-Host "[3/3] Processing XML files..." -ForegroundColor Yellow
  $fileCount = 0
  
  foreach ($xmlFile in $xmlFiles) {
    $fileCount++
    $xmlPath = $xmlFile.XmlFilePath
    $relativePath = $xmlPath.Replace($xmlFile.TempDir, "").TrimStart('\', '/')
    
    Write-Host ""
    Write-Host "Processing file $fileCount of $($xmlFiles.Count): $relativePath" -ForegroundColor Cyan
    $Logger.Info("Processing $fileCount file of ${$xmlFile}: $relativePath")
    
    try {
      # Build parameter hashtable - only include non-empty values
      $commonParams = @{
        ZipPath      = $xmlPath
        OutPath      = $config.OutPath
        DMConfigDir  = $config.DMConfigDir
        DMDll        = $config.DMDll
      }
      
      # Only add LogPath if it's not empty
      if (-not [string]::IsNullOrWhiteSpace($config.LogPath)) {
        $commonParams['LogPath'] = $config.LogPath
      }
      
      # Add switches ONLY if they are TRUE (don't add false switches)
      if ($config.IncludeEmptyValues -eq $true) {
        $commonParams['IncludeEmptyValues'] = $true
      }
      if ($config.PreviewXml -eq $true) {
        $commonParams['PreviewXml'] = $true
      }
      if ($config.CSVMode -eq $true) {
        $commonParams['CSVMode'] = $true
      }
      
      # Process DBObjects
      
      Write-Host "  - Extracting DBObjects..." -ForegroundColor Gray
      DBObjects_Main_PsModule @commonParams
      
      
      # Process Processes
      
      Write-Host "  - Extracting Processes..." -ForegroundColor Gray
      Process_Main_PsModule @commonParams
      
      
      # Process Templates
     
      Write-Host "  - Extracting Templates..." -ForegroundColor Gray
      Templates_Main_PsModule @commonParams
      
      # Process Scripts
      Write-Host "  - Extracting Scripts..." -ForegroundColor Gray
      Scripts_Main_PsModule @commonParams
      
      Write-Host "  ✓ Completed processing: $relativePath" -ForegroundColor Green

      # Table Scripts
      Write-Host "  - Extracting Table Scripts..." -ForegroundColor Gray
      TableScripts_Main_PsModule @commonParams
      Write-Host "  ✓ Completed processing: $relativePath" -ForegroundColor Green

      # Table Scripts
      Write-Host "  - Extracting Format Scripts..." -ForegroundColor Gray
      FormatScripts_Main_PsModule @commonParams
      Write-Host "  ✓ Completed processing: $relativePath" -ForegroundColor Green
    }
    catch {
      $Logger = Get-Logger
      $Logger.Info("  ✗ Error processing file: $relativePath")
      $Logger.Info("    Error: $($_.Exception.Message)")
      Write-Host "  ✗ Error processing file: $relativePath" -ForegroundColor Red
      Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
     
      # Continue processing other files
    }
  }
  
  Write-Host ""
  Write-Host "=== Export Completed Successfully ===" -ForegroundColor Green
  Write-Host "Processed $fileCount XML file(s)" -ForegroundColor Cyan
  Write-Host "Output directory: $($config.OutPath)" -ForegroundColor Cyan
}
catch {
  Write-Host ""
  Write-Host "=== FATAL ERROR ===" -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
   $Logger = Get-Logger
   $Logger.Info("=== FATAL ERROR ===")
   $Logger.Info($_.Exception.Message)
  if ($_.ScriptStackTrace) {
    Write-Host ""
    Write-Host "Stack Trace:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
  }
  throw
}
finally {
  # Cleanup: Remove temporary directories
  if ($xmlFiles) {
    foreach ($xmlFile in $xmlFiles) {
      if ($xmlFile.TempDir -and (Test-Path -LiteralPath $xmlFile.TempDir)) {
        $Logger = Get-Logger
        $Logger.Info("Cleaning up temp directory: $($xmlFile.TempDir)")
        Write-Verbose "Cleaning up temp directory: $($xmlFile.TempDir)"
        Remove-Item -LiteralPath $xmlFile.TempDir -Recurse -Force -ErrorAction SilentlyContinue
      }
    }
  }
}
#endregion
