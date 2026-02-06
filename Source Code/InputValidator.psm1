function InputValidator{
param(
  [string]$DMConfigDir,
  [string]$OutPath,
  [string]$LogPath,
  [switch]$IncludeEmptyValues,
  [switch]$PreviewXml,
  [switch]$CSVMode,
  [string]$DMDll   
)

$scriptDir = $PSScriptRoot

Write-Host "root $scriptDir"
$configPath  = Join-Path $scriptDir 'config.json'

Write-Host $configPath 
$config = $null
"configPath raw = [$configPath]"
"IsNullOrWhiteSpace = $([string]::IsNullOrWhiteSpace($configPath))"

if(Test-Path -LiteralPath $configPath) {
    try{
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    } catch {
        throw "Failed to read/parse config.json at '$configPath': $($_.Exception.Message)"
    }
}
Else{
  throw "The config.json does not exist at '$configPath'"
}

# Merge values: CLI wins; otherwise use config (if present and non-empty for strings)
$DMConfigDirFromConfig = Get-ConfigPropValue $config "DMConfigDir"
$OutPathFromConfig   = Get-ConfigPropValue $config "OutPath"
$LogPathFromConfig   = Get-ConfigPropValue $config "LogPath"
$DMDllFromConfig     = Get-ConfigPropValue $config "DMDll"

Write-Host "DEBUG: Values from config.json:" -ForegroundColor Yellow
Write-Host "  DMConfigDir: '$DMConfigDirFromConfig'" -ForegroundColor Gray
Write-Host "  OutPath:     '$OutPathFromConfig'" -ForegroundColor Gray
Write-Host "  LogPath:     '$LogPathFromConfig'" -ForegroundColor Gray
Write-Host "  DMDll:       '$DMDllFromConfig'" -ForegroundColor Gray
Write-Host ""

if (-not $PSBoundParameters.ContainsKey("DMConfigDir") -and -not [string]::IsNullOrWhiteSpace($DMConfigDirFromConfig)) {
  $DMConfigDir = [string]$DMConfigDirFromConfig
  Write-Host "DEBUG: Using DMConfigDir from config: $DMConfigDir" -ForegroundColor Cyan
}
else {
  Write-Host "DEBUG: DMConfigDir from CLI or empty" -ForegroundColor Gray
}

if (-not $PSBoundParameters.ContainsKey("OutPath") -and -not [string]::IsNullOrWhiteSpace($OutPathFromConfig)) {
  $OutPath = [string]$OutPathFromConfig
  Write-Host "DEBUG: Using OutPath from config: $OutPath" -ForegroundColor Cyan
}
else {
  Write-Host "DEBUG: OutPath from CLI or empty" -ForegroundColor Gray
}

if (-not $PSBoundParameters.ContainsKey("LogPath") -and -not [string]::IsNullOrWhiteSpace($LogPathFromConfig)) {
  $LogPath = [string]$LogPathFromConfig
  Write-Host "DEBUG: Using LogPath from config: $LogPath" -ForegroundColor Cyan
}
else {
  Write-Host "DEBUG: LogPath from CLI or empty" -ForegroundColor Gray
}

if (-not $PSBoundParameters.ContainsKey("DMDll") -and -not [string]::IsNullOrWhiteSpace($DMDllFromConfig)) {
  $DMDll = [string]$DMDllFromConfig
  Write-Host "DEBUG: Using DMDll from config: $DMDll" -ForegroundColor Cyan
}
else {
  Write-Host "DEBUG: DMDll from CLI or empty" -ForegroundColor Gray
}
Write-Host ""

# Switches: only set from config if user didn't pass the switch
# (config can contain true/false)
$IncludeEmptyFromConfig = Get-ConfigPropValue $config "IncludeEmptyValues"
$PreviewXmlFromConfig   = Get-ConfigPropValue $config "PreviewXml"
$CSVModeFromConfig      = Get-ConfigPropValue $config "CSVMode"

# Apply switch values: CLI parameter takes precedence, then config, then default to $false
if ($PSBoundParameters.ContainsKey("IncludeEmptyValues")) {
  # User explicitly passed the switch
  $IncludeEmptyValues = [bool]$IncludeEmptyValues
}
elseif ($IncludeEmptyFromConfig -is [bool]) {
  # Use config value
  $IncludeEmptyValues = [bool]$IncludeEmptyFromConfig
}
else {
  # Default to false
  $IncludeEmptyValues = $false
}

if ($PSBoundParameters.ContainsKey("PreviewXml")) {
  $PreviewXml = [bool]$PreviewXml
}
elseif ($PreviewXmlFromConfig -is [bool]) {
  $PreviewXml = [bool]$PreviewXmlFromConfig
}
else {
  $PreviewXml = $false
}

if ($PSBoundParameters.ContainsKey("CSVMode")) {
  $CSVMode = [bool]$CSVMode
}
elseif ($CSVModeFromConfig -is [bool]) {
  $CSVMode = [bool]$CSVModeFromConfig
}
else {
  $CSVMode = $false
}

# Validate required values AFTER merge
$missing = @()

if ([string]::IsNullOrWhiteSpace($DMConfigDir)) { $missing += "DMConfigDir" }

if ($missing.Count -gt 0) {
  throw "Missing required parameter(s): $($missing -join ', '). Provide via command line or config file '$configPath'."
}

# Optional: normalize paths if they exist
if (-not [string]::IsNullOrWhiteSpace($DMConfigDir) -and (Test-Path -LiteralPath $DMConfigDir)) {
  $DMConfigDir = (Resolve-Path -LiteralPath $DMConfigDir).Path
}
if (-not [string]::IsNullOrWhiteSpace($OutPath)) { 
  # Create output directory if it doesn't exist
  if (-not (Test-Path -LiteralPath $OutPath)) {
    New-Item -ItemType Directory -Path $OutPath -Force | Out-Null
  }
  $OutPath = (Resolve-Path -LiteralPath $OutPath).Path 
}
else {
  # Default OutPath to current directory
  $OutPath = (Get-Location).Path
}

# Handle LogPath - create default if not provided
if ([string]::IsNullOrWhiteSpace($LogPath)) {
  # Default: Logs directory under OutPath
  $LogPath = Join-Path $OutPath "Logs\export.log"
}

# Create log directory if it doesn't exist
$logDir = Split-Path -Parent $LogPath
if ($logDir -and -not (Test-Path -LiteralPath $logDir)) {
  New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

return [pscustomobject]@{ 
  DMConfigDir        = $DMConfigDir
  OutPath            = $OutPath
  LogPath            = $LogPath
  DMDll              = $DMDll
  IncludeEmptyValues = [bool]$IncludeEmptyValues
  PreviewXml         = [bool]$PreviewXml
  CSVMode            = [bool]$CSVMode
}

}

function Get-ConfigPropValue {
  param(
    [object]$Config,
    [string]$Name
  )

  if ($null -eq $Config) { return $null }
  if ($Config.PSObject.Properties.Name -contains $Name) {
    return $Config.$Name
  }
  return $null
}

# Export module members
Export-ModuleMember -Function @(
  'InputValidator'
)
