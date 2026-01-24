function Write-TemplatesAsVbNetFiles {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][object[]]$Templates,
    [Parameter(Mandatory)][string]$OutDir,
    [Parameter(Mandatory)]
    [Microsoft.PowerShell.Commands.WebRequestSession]$Session
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
    $uri = "http://localhost:8182/SupportPlus/GetTableNameColumnName?UID_DialogColumn=$columnKey"

    $headers = @{
      "Accept"             = "application/json"
      "X-Forwarded-For"     = "127.0.0.1"
      "X-Forwarded-Host"    = "localhost:8182"
      "X-Forwarded-Proto"   = "http"
    }

    $res = Invoke-WebRequest -Uri $uri -Method Get -Headers $headers -WebSession $session -ErrorAction Stop
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