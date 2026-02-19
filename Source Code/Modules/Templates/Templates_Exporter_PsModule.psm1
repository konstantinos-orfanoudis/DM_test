function Write-TemplatesAsVbNetFiles {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][object[]]$Templates,
    [Parameter(Mandatory)][string]$OutDir
  )

  if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir | Out-Null
  }

  function Sanitize-FilePart([string]$s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return "" }
    $invalid = [System.IO.Path]::GetInvalidFileNameChars()
    foreach ($ch in $invalid) { $s = $s.Replace($ch, [char]0) }
    $s = $s.Replace('"', '')
    $s -replace '\s+', ''
    return $s.Trim()
  }

  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  $counter = 000
  foreach ($t in $Templates) {
    
    $columnKey = $t.ColumnName
    $s = Open-QSql
    $wc = "select ColumnName, UID_DialogTable from DialogColumn where UID_DialogColumn = '$columnKey'"
    $pr = Find-QSql $wc -dict 
    $uid_table = $pr["UID_DialogTable"]
    $columnName = $pr["ColumnName"]
    $wc = "select TableName from DialogTable where UID_DialogTable = '$uid_table'"
    $t2 = Find-QSql $wc -dict 
    $TableName = $t2["TableName"]
    Close-QSql
    $res = $TableName + "-" + $columnName
    $res = $res -replace '"', ''

    # For overwrite-only changes, the template content is not in the transport XML
    # and must be fetched from the database
    $vbContent = $t.Content
    if ($t.FetchContentFromDb) {
      $s = Open-QSql
      $wc = "select Template from DialogColumn where UID_DialogColumn = '$columnKey'"
      $dbTemplate = Find-QSql $wc -dict
      Close-QSql
      if ($dbTemplate -and $dbTemplate["Template"]) {
        $vbContent = $dbTemplate["Template"]
        Write-Host "  Fetched template content from DB for: $res" -ForegroundColor Cyan
        $Logger = Get-Logger
        $Logger.Info("Fetched template content from DB for: $res")
      }
      else {
        Write-Host "  WARNING: No template content found in DB for: $res (UID_DialogColumn=$columnKey)" -ForegroundColor Yellow
        $Logger = Get-Logger
        $Logger.Info("WARNING: No template content found in DB for: $res (UID_DialogColumn=$columnKey)")
      }
    }

    $suffix = if ($t.IsOverwritingTemplate) { "-o" } else { "" }
    $fileName = "ColumnTemplate_" + $res + $suffix +".vb"
    $fileName = ('{0:D3}-{1}' -f ($counter + 1), $fileName)

    $filePath = Join-Path $OutDir $fileName
    [System.IO.File]::WriteAllText($filePath, [string]$vbContent, $utf8NoBom)

    Write-Host "Wrote template: $filePath" -ForegroundColor Green
    $Logger = Get-Logger
    $Logger.Info("Wrote template: $filePath")
    $counter = $counter + 1
    
  }
}

Export-ModuleMember -Function @('Write-TemplatesAsVbNetFiles')