

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
$ZipPathFromConfig   = Get-ConfigPropValue $config "ZipPath"
$ConfigDirFromConfig = Get-ConfigPropValue $config "ConfigDir"
$OutPathFromConfig   = Get-ConfigPropValue $config "OutPath"
$LogPathFromConfig   = Get-ConfigPropValue $config "LogPath"
$DMDllFromConfig     = Get-ConfigPropValue $config "DMDll"

if (-not $PSBoundParameters.ContainsKey("ZipPath") -and -not [string]::IsNullOrWhiteSpace($ZipPathFromConfig)) {
  $ZipPath = [string]$ZipPathFromConfig
}
if (-not $PSBoundParameters.ContainsKey("ConfigDir") -and -not [string]::IsNullOrWhiteSpace($ConfigDirFromConfig)) {
  $ConfigDir = [string]$ConfigDirFromConfig
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

# Switches: only set from config if user didn't pass the switch
# (config can contain true/false)
$IncludeEmptyFromConfig = Get-ConfigPropValue $config "IncludeEmptyValues"
$PreviewXmlFromConfig   = Get-ConfigPropValue $config "PreviewXml"
$CSVModeFromConfig      = Get-ConfigPropValue $config "CSVMode"

if (-not $PSBoundParameters.ContainsKey("IncludeEmptyValues") -and $IncludeEmptyFromConfig -is [bool]) {
  $IncludeEmptyValues = [bool]$IncludeEmptyFromConfig
}
if (-not $PSBoundParameters.ContainsKey("PreviewXml") -and $PreviewXmlFromConfig -is [bool]) {
  $PreviewXml = [bool]$PreviewXmlFromConfig
}
if (-not $PSBoundParameters.ContainsKey("CSVMode") -and $CSVModeFromConfig -is [bool]) {
  $CSVMode = [bool]$CSVModeFromConfig
}

# Validate required values AFTER merge
$missing = @()

if ([string]::IsNullOrWhiteSpace($ZipPath))   { $missing += "ZipPath" }
if ([string]::IsNullOrWhiteSpace($ConfigDir)) { $missing += "ConfigDir" }

if ($missing.Count -gt 0) {
  $where = if (Test-Path -LiteralPath $ConfigFile) { "command line or config file '$ConfigFile'" } else { "command line (config file '$ConfigFile' not found)" }
  throw "Missing required parameter(s): $($missing -join ', '). Provide via $where."
}

# Optional: normalize paths
$ZipPath   = (Resolve-Path -LiteralPath $ZipPath).Path
$ConfigDir = (Resolve-Path -LiteralPath $ConfigDir).Path
if (-not [string]::IsNullOrWhiteSpace($OutPath)) { $OutPath = (Resolve-Path -LiteralPath $OutPath).Path }
if (-not [string]::IsNullOrWhiteSpace($LogPath)) { $LogPath = (Resolve-Path -LiteralPath $LogPath).Path }


return [pscustomobject]@{ 
                          ZipPath            =           $ZipPath
                          ConfigDir          =           $ConfigDir
                          OutPath            =           $OutPath
                          LogPath            =           $LogPath
                          DMDll              =           $DMDll
                          IncludeEmptyValues =           [bool]$IncludeEmptyValues
                          PreviewXml         =           [bool]$PreviewXml;
                          CSVMode            =           [bool]$CSVMode
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
