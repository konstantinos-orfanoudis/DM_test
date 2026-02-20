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

$scriptDir  = $PSScriptRoot
$configPath = Join-Path $scriptDir 'config.json'

if (Test-Path -LiteralPath $configPath) {
  try {
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
  } catch {
    throw "Failed to read/parse config.json at '$configPath': $($_.Exception.Message)"
  }
} else {
  throw "The config.json does not exist at '$configPath'"
}

# Merge values: CLI wins; otherwise use config (if present and non-empty for strings)
$DMConfigDirFromConfig = Get-ConfigPropValue $config "DMConfigDir"
$OutPathFromConfig     = Get-ConfigPropValue $config "OutPath"
$LogPathFromConfig     = Get-ConfigPropValue $config "LogPath"
$DMDllFromConfig       = Get-ConfigPropValue $config "DMDll"
$DMPasswordFromConfig  = Get-ConfigPropValue $config "DMPassword"

if (-not $PSBoundParameters.ContainsKey("DMConfigDir") -and -not [string]::IsNullOrWhiteSpace($DMConfigDirFromConfig)) {
  $DMConfigDir = [string]$DMConfigDirFromConfig
}
if (-not $PSBoundParameters.ContainsKey("OutPath") -and -not [string]::IsNullOrWhiteSpace($OutPathFromConfig)) {
  $OutPath = [string]$OutPathFromConfig
}
if (-not $PSBoundParameters.ContainsKey("LogPath") -and -not [string]::IsNullOrWhiteSpace($LogPathFromConfig)) {
  $LogPath = [string]$LogPathFromConfig
}
if (-not $PSBoundParameters.ContainsKey("DMDll") -and -not [string]::IsNullOrWhiteSpace($DMDllFromConfig)) {
  $DMDll = [string]$DMDllFromConfig
}

# DMPassword: Always read from config.json (CLI switch triggers credential dialog in MainPsModule)
$DMPassword = ""
if (-not [string]::IsNullOrWhiteSpace($DMPasswordFromConfig)) {
  $DMPassword = [string]$DMPasswordFromConfig
}

# Switches: only set from config if user didn't pass the switch
# (config can contain true/false)
$IncludeEmptyFromConfig = Get-ConfigPropValue $config "IncludeEmptyValues"
$PreviewXmlFromConfig   = Get-ConfigPropValue $config "PreviewXml"
$CSVModeFromConfig      = Get-ConfigPropValue $config "CSVMode"

# Apply switch values: CLI parameter takes precedence, then config, then default to $false
if ($PSBoundParameters.ContainsKey("IncludeEmptyValues")) {
  $IncludeEmptyValues = [bool]$IncludeEmptyValues
} elseif ($IncludeEmptyFromConfig -is [bool]) {
  $IncludeEmptyValues = [bool]$IncludeEmptyFromConfig
} else {
  $IncludeEmptyValues = $false
}

if ($PSBoundParameters.ContainsKey("PreviewXml")) {
  $PreviewXml = [bool]$PreviewXml
} elseif ($PreviewXmlFromConfig -is [bool]) {
  $PreviewXml = [bool]$PreviewXmlFromConfig
} else {
  $PreviewXml = $false
}

if ($PSBoundParameters.ContainsKey("CSVMode")) {
  $CSVMode = [bool]$CSVMode
} elseif ($CSVModeFromConfig -is [bool]) {
  $CSVMode = [bool]$CSVModeFromConfig
} else {
  $CSVMode = $false
}

# Validate required values AFTER merge
$missing = @()
if ([string]::IsNullOrWhiteSpace($DMConfigDir)) { $missing += "DMConfigDir" }

if ($missing.Count -gt 0) {
  throw "Missing required parameter(s): $($missing -join ', '). Provide via command line or config file '$configPath'."
}

# Normalize paths
if (-not [string]::IsNullOrWhiteSpace($DMConfigDir) -and (Test-Path -LiteralPath $DMConfigDir)) {
  $DMConfigDir = (Resolve-Path -LiteralPath $DMConfigDir).Path
}
if (-not [string]::IsNullOrWhiteSpace($OutPath)) {
  if (-not (Test-Path -LiteralPath $OutPath)) {
    New-Item -ItemType Directory -Path $OutPath -Force | Out-Null
  }
  $OutPath = (Resolve-Path -LiteralPath $OutPath).Path
} else {
  $OutPath = (Get-Location).Path
}

# Handle LogPath - create default if not provided
if ([string]::IsNullOrWhiteSpace($LogPath)) {
  $LogPath = Join-Path $OutPath "Logs\export.log"
}

$logDir = Split-Path -Parent $LogPath
if ($logDir -and -not (Test-Path -LiteralPath $logDir)) {
  New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

$TableNameMapCSV = [string](Get-ConfigPropValue $config "TableNameMapCSV")

$ReportOnDenialConfig = Get-ConfigPropValue $config "ReportOnDenial"
$ReportOnDenial = if ($ReportOnDenialConfig -is [bool]) { [bool]$ReportOnDenialConfig } else { $true }

return [pscustomobject]@{
  DMConfigDir        = $DMConfigDir
  OutPath            = $OutPath
  LogPath            = $LogPath
  DMDll              = $DMDll
  DMPassword         = $DMPassword
  IncludeEmptyValues = [bool]$IncludeEmptyValues
  PreviewXml         = [bool]$PreviewXml
  CSVMode            = [bool]$CSVMode
  TableNameMapCSV    = $TableNameMapCSV
  ReportOnDenial     = $ReportOnDenial
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
  'InputValidator',
  'Get-ConfigPropValue'
)
