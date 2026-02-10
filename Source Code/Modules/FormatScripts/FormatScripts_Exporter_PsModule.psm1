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
  $counter = 0
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
    $Logger = Get-Logger
    $Logger.info("The UID_DialogColumn found is: $s")
    $Logger.info("UID_DialogTable found is: $UID_DialogTable")
    $Logger.info("The table found is: $TableName")
    $Logger = Get-Logger
    $Logger.info("The ColumnName Found is:  $ColumnName")
    $Logger.info("The FormatScript is: $FormatScript")
    
    Close-QSql    
    $fileName = "FormatScript_" + $TableName +"-"+$ColumnName+".vb"
    $fileName = ('{0:D3}-{1}' -f ($counter + 1), $fileName)   
    $filePath = Join-Path $OutDir $fileName
    [System.IO.File]::WriteAllText($filePath, $FormatScript, $utf8NoBom)
    Write-Host "Wrote  Format script: $filePath" -ForegroundColor Green
    $Logger = Get-Logger
    $Logger.Info("Wrote script: $filePath")
    $counter = $counter + 1
  }
}

Export-ModuleMember -Function @('Write-FormatScriptsAsVbNetFiles')
