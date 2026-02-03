function Write-ScriptsAsVbNetFiles {
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
    $wc = "select ScriptName, ScriptCode from DialogScript where UID_DialogScript = '$s'"
    $pr = Find-QSql $wc -dict 
    $ScriptCode = $pr["ScriptCode"]
    $ScriptName = $pr["ScriptName"]
    Close-QSql
    
    $fileName = "-" + $ScriptName +".vb"
    $filePath = Join-Path $OutDir $fileName
    [System.IO.File]::WriteAllText($filePath, $ScriptCode, $utf8NoBom)

    Write-Host "Wrote script: $filePath" -ForegroundColor Green
    $Logger = Get-Logger
    $Logger.Info("Wrote script: $filePath")
  }
}

Export-ModuleMember -Function @('Write-ScriptsAsVbNetFiles')
