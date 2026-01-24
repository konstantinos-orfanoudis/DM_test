function Get-TemplatesFromChangeContent {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) { throw "File not found: $Path" }

  # Read whole file + decode a few times (handles &lt; and &amp;lt;)
  $text = Get-Content -LiteralPath $Path -Raw
  for ($i = 0; $i -lt 3; $i++) { $text = [System.Net.WebUtility]::HtmlDecode($text) }

  function Sanitize-FilePart([string]$s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return "" }
    $invalid = [System.IO.Path]::GetInvalidFileNameChars()
    foreach ($ch in $invalid) { $s = $s.Replace($ch, '_') }
    return $s.Trim()
  }

  $reDbObject = [regex]::new('(?s)<DbObject\b.*?</DbObject>')

  # ObjectKey: <Column Name="ObjectKey"> ... <T>DialogColumn</T><P>EPC-...</P> ...
  $reObjectKeyTP = [regex]::new(
    '(?s)<Column\b[^>]*\bName\s*=\s*"ObjectKey"[^>]*>.*?<Value>.*?<T>(.*?)</T>.*?<P>(.*?)</P>.*?</Value>.*?</Column>'
  )

  $reDiff = [regex]::new('(?s)<Diff\b.*?</Diff>')

  # Template value inside Diff (tolerant, does NOT require </Op>)
  $reTemplateValue = [regex]::new(
    "(?s)<Op\b[^>]*(?:Columnname|ColumnName)\s*=\s*[""']Template[""'][^>]*>.*?<Value>(.*?)</Value>"
  )

  $reOverwriteTrue = [regex]::new(
    "(?s)<Op\b[^>]*(?:Columnname|ColumnName)\s*=\s*[""']IsOverwritingTemplate[""'][^>]*>.*?<Value>\s*True\s*</Value>"
  )

  $templates = New-Object System.Collections.Generic.List[object]

  foreach ($dboMatch in $reDbObject.Matches($text)) {
    $dboText = $dboMatch.Value

    # Default context
    $tableName  = "UnknownTable"
    $columnName = "UnknownColumn"

    $mKey = $reObjectKeyTP.Match($dboText)
    if ($mKey.Success) {
      $tableName  = $mKey.Groups[1].Value
      $columnName = $mKey.Groups[2].Value
    }

    $tableName  = Sanitize-FilePart $tableName
    $columnName = Sanitize-FilePart $columnName
    if ([string]::IsNullOrWhiteSpace($tableName))  { $tableName  = "UnknownTable" }
    if ([string]::IsNullOrWhiteSpace($columnName)) { $columnName = "UnknownColumn" }

    foreach ($diffMatch in $reDiff.Matches($dboText)) {
      $diff = $diffMatch.Value

      # Only proceed if this Diff contains a Template Op
      $tm = $reTemplateValue.Matches($diff)
      if ($tm.Count -eq 0) { continue }

      $isOverwrite = $reOverwriteTrue.IsMatch($diff)

      foreach ($m in $tm) {
        # VB file content = inner Template Op <Value>...</Value>
        $vbContent = [System.Net.WebUtility]::HtmlDecode($m.Groups[1].Value).Trim()

        $templates.Add([pscustomobject]@{
          TableName             = $tableName
          ColumnName            = $columnName
          IsOverwritingTemplate = $isOverwrite
          Content               = $vbContent
        })
      }
    }
  }

  return $templates
}
# Export module members
Export-ModuleMember -Function @(
  'Get-TemplatesFromChangeContent'
)
