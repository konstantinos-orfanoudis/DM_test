<#
.SYNOPSIS
  API Client Module - Handles OIM API authentication.

.DESCRIPTION
  This module provides functions to authenticate with the OIM API.
#>

function Connect-OimApi {
  <#
  .SYNOPSIS
    Authenticates with the OIM API and returns a web session.
  
  .PARAMETER BaseUrl
    Base URL of the OIM API (e.g., http://localhost:8182)
  
  .PARAMETER Module
    OIM module name for authentication.
  
  .PARAMETER User
    Username for authentication.
  
  .PARAMETER Password
    Password for authentication.
  
  .OUTPUTS
    Microsoft.PowerShell.Commands.WebRequestSession
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$BaseUrl,
    
    [Parameter(Mandatory)]
    [string]$Module,
    
    [Parameter(Mandatory)]
    [string]$User,
    
    [Parameter(Mandatory)]
    [string]$Password
  )

  $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
  
  $loginUri = "$BaseUrl/imx/login/$Module"
  $body = @{ 
    Module   = "DialogUser"
    User     = $User
    Password = $Password
  } | ConvertTo-Json
  
  try {
    Invoke-WebRequest -Uri $loginUri -Method Post -ContentType "application/json" `
      -Body $body -WebSession $session -ErrorAction Stop | Out-Null
    
    return $session
  }
  catch {
    throw "Failed to authenticate with OIM API: $_"
  }
}


# Export module members
Export-ModuleMember -Function @(
  'Connect-OimApi'
)
