function Write-CanSeeScriptsAsVbNetFiles {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][object[]]$CanSeeScripts,
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

  foreach ($s in $CanSeeScripts) {
    $o = Open-QSql
    $wc = "select ColumnName, CanSeeScript , UID_DialogTable  from DialogColumn where UID_DialogColumn = '$s'"
    $pr = Find-QSql $wc -dict 
    $ColumnName = $pr["ColumnName"]
    write-host  $ColumnName
    $CanSeeScript = $pr["CanSeeScript"]
    write-host $CanSeeScript
    $UID_DialogTable = $pr["UID_DialogTable"]
    write-host $UID_DialogTable
    $wc = "select TableName from DialogTable where UID_DialogTable = '$UID_DialogTable'"
    $t2 = Find-QSql $wc -dict
    $TableName = $t2["TableName"]
    write-host  $TableName
    $Logger = Get-Logger
    $Logger.info("The UID_DialogColumn found is: $s")
    $Logger.info("UID_DialogTable found is: $UID_DialogTable")
    $Logger.info("The Table found is: $TableName")
    $Logger = Get-Logger
    $Logger.info("The ColumnName Found is:  $ColumnName")
    $Logger.info("The CanSeeScript found is: $CanSeeScript")
    Close-QSql
    
    $fileName = "-CanSeeScript_" + $TableName +"-"+$ColumnName+".vb"
    $filePath = Join-Path $OutDir $fileName
    [System.IO.File]::WriteAllText($filePath, $CanSeeScript, $utf8NoBom)

    Write-Host "Wrote  Format script: $filePath" -ForegroundColor Green
    $Logger = Get-Logger
    $Logger.Info("Wrote script: $filePath")
  }
}

Export-ModuleMember -Function @('Write-CanSeeScriptsAsVbNetFiles')
