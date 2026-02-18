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

  $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  $keys = New-Object 'System.Collections.Generic.List[string]'

  foreach ($m in [regex]::Matches($text, $pattern)) {
    $k = $m.Groups['p'].Value.Trim()
    if ($k -and $seen.Add($k)) {
      [void]$keys.Add($k)
    }
  }

  return $keys
}

# Export module members
Export-ModuleMember -Function @(
  'Get-ScriptKeysFromChangeLabel'
)
