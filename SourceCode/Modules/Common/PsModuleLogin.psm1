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
  
  .PARAMETER DMConfigDir
    Configuration directory path (used for connection config).
  
  .PARAMETER DMDll
    Path to DeploymentManager DLL.
  
  .PARAMETER OutPath
    Output directory path (used as DeploymentPath for Invoke-QDeploy).
    
  .OUTPUTS
    Session object
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$DMConfigDir,

    [Parameter(Mandatory)]
    [string]$DMDll,

    [Parameter(Mandatory)]
    [string]$OutPath
  )

  try {
    Write-Host "  Loading DeploymentManager DLL: $DMDll" -ForegroundColor Gray
    Import-Module $DMDll
    
    Write-Host "  Connecting with config: $DMConfigDir" -ForegroundColor Gray
    Write-Host "  Using deployment path: $DMConfigDir" -ForegroundColor Gray
    Invoke-QDeploy -Console -DeploymentPath $DMConfigDir
    
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
