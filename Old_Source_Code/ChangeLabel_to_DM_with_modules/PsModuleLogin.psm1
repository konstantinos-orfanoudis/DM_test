<#
.SYNOPSIS
  PowerShell Module Login - Handles OIM connection via PowerShell module.

.DESCRIPTION
  This module provides functions to connect to OIM via DeploymentManager PowerShell module.
#>

function Connect-OimPSModule {
  <#
  .SYNOPSIS
    Connects to OIM using DeploymentManager PowerShell module.
  
  .PARAMETER ConfigDir
    Configuration directory path.
  
  .PARAMETER DMDll
    Path to DeploymentManager DLL.
    
  .OUTPUTS
    Session object
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$ConfigDir,

    [Parameter(Mandatory)]
    [string]$DMDll
  )

  try {
    Import-Module $DMDll
    Invoke-QDeploy -Console -DeploymentPath $ConfigDir
    $session = Get-QSession -default 
    
    return $session
  }
  catch {
    throw "Failed to connect to OIM: $_"
  }
}

# Export module members
Export-ModuleMember -Function @(
  'Connect-OimPSModule'
)
