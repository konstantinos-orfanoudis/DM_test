function Write-FormatScriptsAsVbNetFiles {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][object[]]$Scripts,
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

  foreach ($s in $Scripts) {
    $o = Open-QSql
    $wc = "select ColumnName, FormatScript , UID_DialogTable  from DialogColumn where UID_DialogColumn = '$s'"
    $pr = Find-QSql $wc -dict 
    $ColumnName = $pr["ColumnName"]
    write-host  $ColumnName
    $FormatScript = $pr["FormatScript"]
    write-host $FormatScript
    $UID_DialogTable = $pr["UID_DialogTable"]
    write-host $UID_DialogTable
    $wc = "select TableName from DialogTable where UID_DialogTable = '$UID_DialogTable'"
    $t2 = Find-QSql $wc -dict
    $TableName = $t2["TableName"]
    write-host  $TableName
    Close-QSql
    
    $fileName = "-FormatScript_" + $TableName +"-"+$ColumnName+".vb"
    write-host $fileName
    $filePath = Join-Path $OutDir $fileName
    [System.IO.File]::WriteAllText($filePath, $FormatScript, $utf8NoBom)

    Write-Host "Wrote  Format script: $filePath" -ForegroundColor Green
    $Logger = Get-Logger
    $Logger.Info("Wrote script: $filePath")
  }
}

Export-ModuleMember -Function @('Write-FormatScriptsAsVbNetFiles')
