<#
.SYNOPSIS
  PowerShell Module Login - Handles OIM connection via PowerShell module.

.DESCRIPTION
  This module provides functions to connect to OIM via DeploymentManager PowerShell module.
  Supports encrypted passwords using ConvertFrom-EncryptedBlock.
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
  
  .PARAMETER DMPassword
    Password for encrypted configurations (plain text or encrypted with [E] prefix).
    
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
    [string]$OutPath,

    [Parameter(Mandatory = $false)]
    [string]$DMPassword = ""
  )

  try {
    Write-Host "  Loading DeploymentManager DLL: $DMDll" -ForegroundColor Gray
    Import-Module $DMDll
    
    Write-Host "  Connecting with config: $DMConfigDir" -ForegroundColor Gray
    
    # Handle password if provided
    if (-not [string]::IsNullOrWhiteSpace($DMPassword)) {
      $plainPassword = $DMPassword
      
      # Check if password is encrypted (starts with [E])
      if ($DMPassword -match '^\[E\]') {
        Write-Host "  Decrypting encrypted password..." -ForegroundColor Gray
        
        try {
          # Import PasswordEncryption module (it's in project root)
          # $PSScriptRoot is Modules/Common/, so go up 2 levels to project root
          $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
          $modulePath = Join-Path $projectRoot "PasswordEncryption.psm1"
          
          if (Test-Path $modulePath) {
            Import-Module $modulePath -Force
          } else {
            throw "PasswordEncryption.psm1 not found at: $modulePath"
          }
          
          $plainPassword = ConvertFrom-EncryptedBlock $DMPassword
          Write-Host "  ✓ Password decrypted successfully" -ForegroundColor Green
        }
        catch {
          Write-Error "Failed to decrypt password: $_"
          throw "Password decryption failed. Ensure password was encrypted on this machine by this user."
        }
      }
      else {
        Write-Host "  Using plain text password" -ForegroundColor Yellow
        Write-Host "  ⚠ Consider encrypting with: ConvertTo-EncryptedBlock" -ForegroundColor Yellow
      }
      
      # Use the password (decrypted or plain)
      Write-Host "  Connecting with password..." -ForegroundColor Gray
      Invoke-QDeploy -Console -DeploymentPath $DMConfigDir -Password $plainPassword
    }
    else {
      Write-Host "  Connecting without password..." -ForegroundColor Gray
      Invoke-QDeploy -Console -DeploymentPath $DMConfigDir
    }
    
    $session = Get-QSession -default 
    
    if ($null -eq $session) {
      throw "Failed to establish session - Get-QSession returned null"
    }
    
    Write-Host "  ✓ Connection established successfully" -ForegroundColor Green
    
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
