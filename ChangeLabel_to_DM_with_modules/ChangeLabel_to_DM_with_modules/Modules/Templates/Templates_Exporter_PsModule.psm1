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

  foreach ($t in $Templates) {

      $columnKey = $t.ColumnName
      $s = Open-QSql
      $wc = "select ColumnName, UID_DialogTable from DialogColumn where UID_DialogColumn = '$columnKey'"
      $pr = Find-QSql $wc -dict 
      $uid_table = $pr["UID_DialogTable"]
      $columnName = $pr["ColumnName"]
      Write-Host $columnName + "paizei 133"
      $wc = "select TableName from DialogTable where UID_DialogTable = '$uid_table'"
      $t = Find-QSql $wc -dict 
      $TableName = $t["TableName"]
      Close-QSql
      $res = $TableName + "-" + $columnName
    
    

      $res = $res -replace '"', ''


    $suffix = if ($t.IsOverwritingTemplate) { "-o" } else { "" }
    $fileName = "ColumnTemplate_" + $res + $suffix +".vb"

    $filePath = Join-Path $OutDir $fileName
    Write-Host $filePath
    [System.IO.File]::WriteAllText($filePath, [string]$t.Content, $utf8NoBom)

    Write-Host "Wrote template: $filePath" -ForegroundColor Green
  }


}

# Export module members
Export-ModuleMember -Function @(
  'Write-TemplatesAsVbNetFiles'
)