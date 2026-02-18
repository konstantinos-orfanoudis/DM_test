<#
.SYNOPSIS
  Password Encryption Module - Provides functions to encrypt/decrypt passwords.

.DESCRIPTION
  This module provides functions to encrypt and decrypt passwords using Windows DPAPI.
  Encrypted passwords are machine and user-specific.
  
  Based on TestHelpers.psm1 encryption functions.
#>

Function ConvertTo-EncryptedBlock {
  <#
  .SYNOPSIS
    Encrypt clear text to a block of cypher. Can only be decrypted by the same user on the machine!
  
  .PARAMETER ClearText
    The text to encrypt.
  
  .OUTPUTS
    The encrypted data block prefixed with [E].
  
  .EXAMPLE
    ConvertTo-EncryptedBlock 'my secret'
  
  .EXAMPLE
    'MyPassword123' | ConvertTo-EncryptedBlock
  #>
  param(
    [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Mandatory=$true)]
    [string[]]$ClearText
  )
  process {
    $ClearText | ForEach-Object {
      $block = (ConvertTo-SecureString -Force -AsPlainText -String $_) | ConvertFrom-SecureString
      $enc = "[E]{0}" -f $block
      Write-Output ($enc -replace ".{79}", "`$0`r`n")
    }
  }
}

Function ConvertFrom-EncryptedBlock {
  <#
  .SYNOPSIS
    Decrypt a block of cypher to clear text. Can only decrypt cypher encrypted by the same user on the same machine!
  
  .PARAMETER Encrypted
    The block to decrypt (with or without [E] prefix).
  
  .OUTPUTS
    The clear text.
  
  .EXAMPLE
    ConvertTo-EncryptedBlock 'my secret' | ConvertFrom-EncryptedBlock 
  
  .EXAMPLE
    ConvertFrom-EncryptedBlock '[E]encrypted_string_here'
  #>
  param(
    [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Mandatory=$true)]
    [string[]]$Encrypted
  )
  process {
    $Encrypted | ForEach-Object {
      $crypt = ($_ -replace "^\[E\]", "" -replace "`r|`n|\s", "")
      Write-Output (New-Object pscredential "user", ($crypt | ConvertTo-SecureString -ErrorAction Stop)).GetNetworkCredential().Password
    }
  }
}

# Export module members
Export-ModuleMember -Function @(
  'ConvertTo-EncryptedBlock',
  'ConvertFrom-EncryptedBlock'
)
