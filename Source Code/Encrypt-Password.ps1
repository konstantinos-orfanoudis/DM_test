<#
.SYNOPSIS
  Helper script to encrypt passwords for use in config.json

.DESCRIPTION
  This script encrypts a password using Windows DPAPI (machine + user specific).
  The encrypted password can be stored in config.json and will be automatically
  decrypted when the tool runs.
  
  IMPORTANT: Encrypted passwords are machine and user-specific!
  - Password encrypted on Machine A by User1 only works on Machine A for User1
  - Must re-encrypt on each machine/user combination

.PARAMETER Password
  The plain text password to encrypt. If not provided, will prompt securely.

.EXAMPLE
  .\Encrypt-Password.ps1
  # Prompts securely for password

.EXAMPLE
  .\Encrypt-Password.ps1 -Password "MyPassword123"
  # Encrypts the provided password

.EXAMPLE
  # Copy to clipboard (Windows):
  .\Encrypt-Password.ps1 -Password "MyPassword123" | Set-Clipboard
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$Password
)

# Import the encryption module
$scriptDir = $PSScriptRoot
$modulePath = Join-Path $scriptDir "PasswordEncryption.psm1"

if (-not (Test-Path $modulePath)) {
  Write-Host "ERROR: PasswordEncryption.psm1 not found at: $modulePath" -ForegroundColor Red
  Write-Host "Ensure Encrypt-Password.ps1 is in the same directory as PasswordEncryption.psm1" -ForegroundColor Yellow
  exit 1
}

Import-Module $modulePath -Force

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          Password Encryption Tool                             ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Get password if not provided
if ([string]::IsNullOrWhiteSpace($Password)) {
  Write-Host "Enter password to encrypt (input will be hidden):" -ForegroundColor Yellow
  $securePassword = Read-Host -AsSecureString
  $Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
  )
}

if ([string]::IsNullOrWhiteSpace($Password)) {
  Write-Host "ERROR: No password provided" -ForegroundColor Red
  exit 1
}

Write-Host "Encrypting password..." -ForegroundColor Gray
Write-Host ""

try {
  # Encrypt the password
  $encrypted = ConvertTo-EncryptedBlock $Password
  
  Write-Host "✓ Password encrypted successfully!" -ForegroundColor Green
  Write-Host ""
  Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
  Write-Host "Encrypted password (copy this to config.json):" -ForegroundColor Yellow
  Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
  Write-Host ""
  Write-Output $encrypted
  Write-Host ""
  Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
  Write-Host ""
  Write-Host "Usage in config.json:" -ForegroundColor Yellow
  Write-Host @"
{
  "DMConfigDir": "C:\\Path\\To\\Config",
  "OutPath": "C:\\Output",
  "DMDll": "C:\\Path\\To\\Intragen.Deployment.OneIdentity.dll",
  "DMPassword": "$($encrypted.Split("`n")[0])...",
  ...
}
"@ -ForegroundColor Gray
  Write-Host ""
  Write-Host "⚠ IMPORTANT: This password is machine + user specific!" -ForegroundColor Yellow
  Write-Host "  • Only works on this machine: $env:COMPUTERNAME" -ForegroundColor Gray
  Write-Host "  • Only works for this user:   $env:USERNAME" -ForegroundColor Gray
  Write-Host "  • Must re-encrypt on different machines/users" -ForegroundColor Gray
  Write-Host ""
  
  # Test decryption
  Write-Host "Testing decryption..." -ForegroundColor Gray
  $decrypted = ConvertFrom-EncryptedBlock $encrypted
  
  if ($decrypted -eq $Password) {
    Write-Host "✓ Decryption test passed!" -ForegroundColor Green
  } else {
    Write-Host "✗ Decryption test failed!" -ForegroundColor Red
  }
  Write-Host ""
}
catch {
  Write-Host "ERROR: Failed to encrypt password" -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  exit 1
}

Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Copy the encrypted password above" -ForegroundColor Gray
Write-Host "  2. Add to config.json as 'DMPassword' field" -ForegroundColor Gray
Write-Host "  3. Run the tool normally - password will be decrypted automatically" -ForegroundColor Gray
Write-Host ""
