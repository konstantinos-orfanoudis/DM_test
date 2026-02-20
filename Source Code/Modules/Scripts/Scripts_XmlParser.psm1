Import-Module "$PSScriptRoot\..\Common\XDateCheck.psm1" -Force

function Get-ScriptKeysFromChangeLabel {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrWhiteSpace()]
    [string]$ZipPath,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrWhiteSpace()]
    [string]$TypeName = "DialogScript"   # the <T> value to match
  )
  $Logger = Get-Logger
  if (-not (Test-Path -LiteralPath $ZipPath)) {
    $Logger = Get-Logger
    $Logger.Info("File not found: $ZipPath")
    throw "File not found: $ZipPath"
  }

  $text = Get-Content -LiteralPath $ZipPath -Raw

  # Decode entities a few times (safe even if already decoded)
  for ($i = 0; $i -lt 3; $i++) {
    $text = [System.Net.WebUtility]::HtmlDecode($text)
  }

  # Match: <T>DialogScript</T><P>...</P> (allow whitespace/newlines)
  $pattern = '(?is)<T>\s*' + [regex]::Escape($TypeName) + '\s*</T>\s*<P>\s*(?<p>[^<\s]+)\s*</P>'
  $dbObjectPattern = '(?is)<DbObject\b.*?>.*?</DbObject>'

  $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  $keys = New-Object 'System.Collections.Generic.List[string]'

  foreach ($dbMatch in [regex]::Matches($text, $dbObjectPattern)) {
    $dbText = $dbMatch.Value

    foreach ($m in [regex]::Matches($dbText, $pattern)) {
      $k = $m.Groups['p'].Value.Trim()
      if ($k -and $seen.Add($k)) {
        # --- XDateUpdated freshness check ---
        $transportDate = Get-XDateUpdatedFromBlock -Block $dbText
        $allow = Confirm-ExportIfStale -TableName $TypeName `
                   -WhereClause "UID_$TypeName = '$k'" `
                   -TransportXDateUpdated $transportDate `
                   -ObjectDescription "$TypeName (UID = $k)"
        if (-not $allow) { continue }
        [void]$keys.Add($k)
      }
    }
  }

  return $keys
}

# Export module members
Export-ModuleMember -Function @(
  'Get-ScriptKeysFromChangeLabel'
)
