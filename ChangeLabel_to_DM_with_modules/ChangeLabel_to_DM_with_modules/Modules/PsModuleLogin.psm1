<#
.SYNOPSIS
  API Client Module - Handles OIM API authentication.

.DESCRIPTION
  This module provides functions to authenticate with the OIM API.
#>

function Connect-OimPSModule {
  <#
  .SYNOPSIS
    Authenticates with the OIM API and returns a web session.
  
  .PARAMETER Config

  .PARAMETER DMDll
    
  .OUTPUTS
    Microsoft.PowerShell.Commands.WebRequestSession
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$ConfigDir,

    [Parameter(Mandatory)]
    [string]$DMDll
    
    
  )

  

  try {
    Import-Module "C:\Users\aiuser\Desktop\DeploymentManager-4.0.6-beta\Intragen.Deployment.OneIdentity.dll"
    #Import-Module $DMDll
    Invoke-QDeploy -Console -DeploymentPath C:\DMWorkshop2\Config\Example
    #Invoke-QDeploy -Console -DeploymentPath $ConfigDir
    $session = Get-QSession -default 
    
    return $session
  }
  catch {
    throw "Failed to authenticate with OIM API: $_"
  }
}


# Export module members
Export-ModuleMember -Function @(
  'Connect-OimPSModule'
)
