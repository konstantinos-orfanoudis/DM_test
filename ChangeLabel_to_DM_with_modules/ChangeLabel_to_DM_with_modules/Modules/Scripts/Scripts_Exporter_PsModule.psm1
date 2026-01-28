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

    Write-Host "Script: " + $s
    $o = Open-QSql
    $wc = "select ScriptName, ScriptCode from DialogScript where UID_DialogScript = '$s'"
    $pr = Find-QSql $wc -dict 
    Write-Host "Script object " + $pr
    $ScriptCode = $pr["ScriptCode"]
    $ScriptName = $pr["ScriptName"]
    Write-Host $ScriptName + "paizei 32"
    
    Close-QSql
    
    $fileName = "-" + $ScriptName +".vb"

    $filePath = Join-Path $OutDir $fileName
    Write-Host $filePath
    [System.IO.File]::WriteAllText($filePath, $ScriptCode, $utf8NoBom)

    Write-Host "Wrote script: $filePath" -ForegroundColor Green
  }


}

# Export module members
Export-ModuleMember -Function @(
  'Write-ScriptsAsVbNetFiles'
)