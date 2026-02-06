function Write-ScriptsAsVbNetFiles {
  <#
  .SYNOPSIS
    Writes script objects to .vb files on disk.
  
  .DESCRIPTION
    Takes script objects (with UID, ScriptName, ScriptCode properties)
    and writes each to a separate .vb file.
  
  .PARAMETER Scripts
    Array of script objects from the parser.
  
  .PARAMETER OutDir
    Output directory for .vb files.
  #>
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
    foreach ($ch in $invalid) { $s = $s.Replace($ch, '_') }
    $s = $s.Replace('"', '')
    return $s.Trim()
  }

  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

  $count = 0
  foreach ($script in $Scripts) {
    # Script objects from parser have UID, ScriptName, and ScriptCode properties
    $scriptName = Sanitize-FilePart $script.ScriptName
    $scriptCode = $script.ScriptCode

    if ([string]::IsNullOrWhiteSpace($scriptName)) {
      $scriptName = "UnknownScript_" + $script.UID.Substring(0, 8)
    }

    if ([string]::IsNullOrWhiteSpace($scriptCode)) {
      Write-Warning "Script $scriptName has no code, skipping"
      continue
    }

    # Create filename: ScriptName.vb
    $fileName = "$scriptName.vb"
    $filePath = Join-Path $OutDir $fileName

    # Write script code to file
    try {
      [System.IO.File]::WriteAllText($filePath, $scriptCode, $utf8NoBom)
      Write-Host "  ✓ Wrote script: $fileName" -ForegroundColor Green
      $count++
    }
    catch {
      Write-Warning "Failed to write script $fileName`: $_"
    }
  }

  Write-Host "`nWrote $count script file(s)" -ForegroundColor Cyan
}

# Export module members
Export-ModuleMember -Function @(
  'Write-ScriptsAsVbNetFiles'
)