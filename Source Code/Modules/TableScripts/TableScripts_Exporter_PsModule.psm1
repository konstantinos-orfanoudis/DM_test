function Write-TableScriptsAsVbNetFiles {
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
  $counter = 000
  foreach ($s in $Scripts) {
    $o = Open-QSql
    $UID_DialogTable = $s.UID_DialogTable
    $wc = "select TableName, OnSavingScript,OnSavedScript,OnLoadedScript,OnDiscardedScript,OnDiscardingScript from DialogTable where UID_DialogTable = '$UID_DialogTable'"
    $pr = Find-QSql $wc -dict 
    $TableName = $pr["TableName"]
    $OnSavingScript = $pr["OnSavingScript"]
    $OnSavedScript = $pr["OnSavedScript"]
    $OnLoadedScript = $pr["OnLoadedScript"]
    $OnDiscardedScript = $pr["OnDiscardedScript"]
    $OnDiscardingScript = $pr["OnDiscardingScript"]
    Close-QSql
    
    If($s.OnSavingScript){
      
       $fileName = "TableScript_" + $TableName +"_saving" + ".vb"
       $fileName = ('{0:D3}-{1}' -f ($counter + 1), $fileName)
       $filePath = Join-Path $OutDir $fileName
       [System.IO.File]::WriteAllText($filePath, $OnSavingScript, $utf8NoBom)

      Write-Host "Wrote OnSavingScript: $filePath" -ForegroundColor Green
      $Logger = Get-Logger
      $Logger.Info("Wrote OnSavingScript: $filePath")
      $counter = $counter + 1
    }

    If($s.OnSavedScript){
       $Logger = Get-Logger
       $fileName = "TableScript_" + $TableName +"_saved" + ".vb"
       $fileName = ('{0:D3}-{1}' -f ($counter + 1), $fileName)
       $filePath = Join-Path $OutDir $fileName
       [System.IO.File]::WriteAllText($filePath, $OnSavedScript, $utf8NoBom)

      Write-Host "Wrote OnSavedScript: $filePath" -ForegroundColor Green
      $Logger.Info("Wrote OnSavedScript: $filePath")
      $counter = $counter + 1
    }

    If($s.OnLoadedScript){
       $fileName = "TableScript_" + $TableName +"_loaded" + ".vb"
       $fileName = ('{0:D3}-{1}' -f ($counter + 1), $fileName)
       $filePath = Join-Path $OutDir $fileName
       [System.IO.File]::WriteAllText($filePath, $OnLoadedScript, $utf8NoBom)

      Write-Host "Wrote OnLoadedScript: $filePath" -ForegroundColor Green
      $Logger = Get-Logger
      $Logger.info("Wrote OnLoadedScript: $filePath")
      $counter = $counter + 1
    }

    If($s.OnDiscardedScript){
       $fileName = "TableScript_" + $TableName +"_discarded" + ".vb"
       $fileName = ('{0:D3}-{1}' -f ($counter + 1), $fileName)
       $filePath = Join-Path $OutDir $fileName
       [System.IO.File]::WriteAllText($filePath, $OnDiscardedScript, $utf8NoBom)

      Write-Host "Wrote OnDiscardedScript: $filePath" -ForegroundColor Green
      $Logger = Get-Logger
      $Logger.info("Wrote OnDiscardedScript: $filePath")
      $counter = $counter + 1
    }

    If($s.OnDiscardingScript){
       $fileName = "TableScript_" + $TableName +"_discarding" + ".vb"
       $fileName = ('{0:D3}-{1}' -f ($counter + 1), $fileName)
       $filePath = Join-Path $OutDir $fileName
       [System.IO.File]::WriteAllText($filePath, $OnDiscardingScript, $utf8NoBom)

      Write-Host "Wrote OnDiscardingScript: $filePath" -ForegroundColor Green
       $Logger = Get-Logger
       $Logger.info("Wrote OnDiscardingScript: $filePath")
       $counter = $counter + 1
    }

    
  }
}

Export-ModuleMember -Function @('Write-TableScriptsAsVbNetFiles')
