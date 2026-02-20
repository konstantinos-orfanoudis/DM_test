Import-Module "$PSScriptRoot\..\Common\XDateCheck.psm1" -Force

function Get-CanSeeScriptsFromChangeLabel {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrWhiteSpace()]
    [string]$ZipPath,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrWhiteSpace()]
    [string]$TypeName = "DialogColumn"   # the <T> value to match
  )

  if (-not (Test-Path -LiteralPath $ZipPath)) {
    throw "File not found: $ZipPath"
  }

  $text = Get-Content -LiteralPath $ZipPath -Raw

  # Decode entities a few times (safe even if already decoded)
  for ($i = 0; $i -lt 3; $i++) {
    $text = [System.Net.WebUtility]::HtmlDecode($text)
  }

  $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  $keys = New-Object 'System.Collections.Generic.List[string]'

  $dbObjectPattern = '(?is)<DbObject\b.*?>.*?</DbObject>'
  $pattern = '(?is)<T>\s*' + [regex]::Escape($TypeName) + '\s*</T>\s*<P>\s*(?<p>[^<\s]+)\s*</P>'

  foreach ($db in [regex]::Matches($text, $dbObjectPattern)) {
    $dbText = $db.Value
    if ($dbText -notmatch 'Columnname\s*=\s*"CanSeeScript"') { continue }

    foreach ($m in [regex]::Matches($dbText, $pattern)) {
      $k = $m.Groups['p'].Value.Trim()
      if ($k -and $seen.Add($k)) {
        # --- XDateUpdated freshness check ---
        $transportDate = Get-XDateUpdatedFromBlock -Block $dbText
        $allow = Confirm-ExportIfStale -TableName 'DialogColumn' `
                   -WhereClause "UID_DialogColumn = '$k'" `
                   -TransportXDateUpdated $transportDate `
                   -ObjectDescription "DialogColumn (CanSeeScript, UID = $k)"
        if (-not $allow) { continue }
        [void]$keys.Add($k)
      }
    }
  }

  return $keys
}

# Export module members
Export-ModuleMember -Function @(
  'Get-CanSeeScriptsFromChangeLabel'
)
