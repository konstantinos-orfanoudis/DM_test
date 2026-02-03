function global:Get-FunctionName ([int]$StackNumber = 2) {return [string]$(Get-PSCallStack)[$StackNumber].FunctionName}

 

#Logger code starting here.



#Logger code starting here.

function global:Get-FunctionName ([int]$StackNumber = 1) {return [string]$(Get-PSCallStack)[$StackNumber].FunctionName}

 

function global:Get-Logger() {



  $modulesDir = Split-Path -Parent $PSScriptRoot

  Write-Host "ModulesDir: $modulesDir"

  $sourceDir = Split-Path -Parent $modulesDir
  Import-Module (Join-Path $sourceDir "InputValidator.psm1") -Force

Write-Host "root $sourceDir"
$configPath  = Join-Path $sourceDir 'config.json'




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


$LogPath = Get-ConfigPropValue $config "LogPath"

#$NlogPath = Get-ConfigPropValue $config "NlogPath"






  Add-Type -Path 'C:\Program Files\One Identity\One Identity Manager\NLog.dll'

  Write-Host "  LogPath: $($config.LogPath)" -ForegroundColor Gray

  $method = Get-FunctionName -StackNumber 2

  $NLogLevel = "Trace" #Setup log level(Valid Values Info,Debug,Trace)

  $logCfg  = Get-NewLogConfig

  $debugLog           = Get-NewLogTarget -targetType "file"

  $debugLog.archiveEvery    = "Day"

  $debugLog.ArchiveNumbering  = "Rolling"

  $debugLog.CreateDirs    = $true

  $debugLog.FileName      = $LogPath #Setup logfile path

  $debugLog.Encoding      = [System.Text.Encoding]::GetEncoding("utf-8")

  $debugLog.KeepFileOpen    = $false

  $debugLog.Layout      = Get-LogMessageLayout -layoutId 3 -method $method

  $debugLog.maxArchiveFiles   = 7

  $debugLog.archiveFileName   = "$LogPath{#}.log" #Setup logfile path

  $logCfg.AddTarget("file", $debugLog)

  $console          = Get-NewLogTarget -targetType "console"

  $console.Layout       = Get-LogMessageLayout -layoutId 2 -method $method

  $logCfg.AddTarget("console", $console)

 

    If ($NLogLevel -eq "Trace") {

      $rule1 = New-Object NLog.Config.LoggingRule("Logger", [NLog.LogLevel]::Trace, $debugLog)

      $logCfg.LoggingRules.Add($rule1)

    }else

    {

        $rule1 = New-Object NLog.Config.LoggingRule("Logger", [NLog.LogLevel]::Trace, $console)

      $logCfg.LoggingRules.Add($rule1)

    }

  $rule2 = New-Object NLog.Config.LoggingRule("Logger", [NLog.LogLevel]::Info, $debugLog)

  $logCfg.LoggingRules.Add($rule2)

  

    If ($NLogLevel -eq "Debug") {

      $rule3 = New-Object NLog.Config.LoggingRule("Logger", [NLog.LogLevel]::Debug, $debugLog)

      $logCfg.LoggingRules.Add($rule3)

    }

 

  [NLog.LogManager]::Configuration = $logCfg

 

  $Log = Get-NewLogger -loggerName "Logger"

  

    return $Log

}

 

function global:Get-NewLogger() {

    param ( [parameter(mandatory=$true)] [System.String]$loggerName )

  

    [NLog.LogManager]::GetLogger($loggerName)

}

 

function global:Get-NewLogConfig() {

 

  New-Object NLog.Config.LoggingConfiguration

}

 

function global:Get-NewLogTarget() {

  param ( [parameter(mandatory=$true)] [System.String]$targetType )

  switch ($targetType) {

    "console" {

      New-Object NLog.Targets.ColoredConsoleTarget 

    }

    "file" {

      New-Object NLog.Targets.FileTarget

    }

    "mail" {

      New-Object NLog.Targets.MailTarget

    }

  }

 

}

 

function global:Get-LogMessageLayout() {

  param (

        [parameter(mandatory=$true)]

        [System.Int32]$layoutId,

        [parameter(mandatory=$false)]

        [String]$method,

        [parameter(mandatory=$false)]

        [String]$Object

    )

  switch ($layoutId) {

    1 {

      $layout = '${longdate} | ${machinename} | ${processid} | ${processname} | ${level} | ${logger} | ${message}'

    }

    2 {

      $layout = '${longdate} | ${machinename} | ${processid} | ${processname} | ${level} | ${logger} | ${message}'

    }

        3 {

      $layout = '${longdate} [${level}] (${processid}) ' + $($method) +' | '  + $($Object) +' ${message}'

    }

  }

  return $layout

}


# Export module members
Export-ModuleMember -Function @(
  'Get-Logger'
)