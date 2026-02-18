function global:Get-FunctionName ([int]$StackNumber = 2) {return [string]$(Get-PSCallStack)[$StackNumber].FunctionName}

 

#region Logger Initialization


  $configPath = Join-Path $PSScriptRoot 'config.json'
  $config = Get-Content $configPath -Raw | ConvertFrom-Json
  $Nloggerdll = [string]$config.NLoggerDLL
  Add-Type -Path $Nloggerdll
  #endregion

function global:Get-FunctionName ([int]$StackNumber = 1) {return [string]$(Get-PSCallStack)[$StackNumber].FunctionName}

 

function global:Get-Logger() {


  $configPath = Join-Path $PSScriptRoot 'config.json'
  $config = Get-Content $configPath -Raw | ConvertFrom-Json
  $LogPath = [string]$config.LogPath  
  $FinalLogPath = $LogPath + "\ultimo_log.log"
  $ArchiveLogPath = $LogPath + "\ultimo_log"
 



  $method = Get-FunctionName -StackNumber 2

  $NLogLevel = "Trace" # Valid values: Trace, Debug, Info

  $logCfg  = Get-NewLogConfig

  $debugLog  = Get-NewLogTarget -targetType "file"

  $debugLog.archiveEvery    = "Day"

  $debugLog.ArchiveNumbering  = "Rolling"

  $debugLog.CreateDirs    = $true

  $debugLog.FileName      =  $FinalLogPath # Log file path

  $debugLog.Encoding      = [System.Text.Encoding]::GetEncoding("utf-8")

  $debugLog.KeepFileOpen    = $false

  $debugLog.Layout      = Get-LogMessageLayout -layoutId 3 -method $method

  $debugLog.maxArchiveFiles   = 7

  $debugLog.archiveFileName   = "$ArchiveLogPath{#}.log" # Archive log file path pattern

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