function Resolve-TagDataXmlFromZip {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ZipPath
  )

  if (-not (Test-Path -LiteralPath $ZipPath)) {
    throw "ZIP file not found: $ZipPath"
  }

  if ([System.IO.Path]::GetExtension($ZipPath) -ne ".zip") {
    throw "Input -Path must be a .zip file. Got: $ZipPath"
  }

  $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("TagTransport_" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $tempDir | Out-Null

  try {
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $tempDir -Force

    $tagTransportDir = Get-ChildItem -LiteralPath $tempDir -Directory -Recurse |
      Where-Object { $_.Name -eq "TagTransport" } |
      Select-Object -First 1

    if (-not $tagTransportDir) {
      throw "Could not find a 'TagTransport' folder inside the zip."
    }

    $tagDataFiles = Get-ChildItem -LiteralPath $tagTransportDir.FullName -Recurse -File -Filter "TagData.xml"

    if (-not $tagDataFiles -or $tagDataFiles.Count -eq 0) {
      throw "Could not find TagData.xml under: $($tagTransportDir.FullName)"
    }

    if ($tagDataFiles.Count -gt 1) {
      Write-Host "Warning: Multiple TagData.xml files found. Using the first one:" -ForegroundColor Yellow
      Write-Host "  $($tagDataFiles[0].FullName)" -ForegroundColor Yellow
    }

    return [pscustomobject]@{
      TempDir         = $tempDir
      TagDataXmlPath  = $tagDataFiles[0].FullName
    }
  }
  catch {
    # if we fail, clean up tempDir before throwing
    if (Test-Path -LiteralPath $tempDir) {
      Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    throw
  }
}
# Export module members
Export-ModuleMember -Function @(
  'Resolve-TagDataXmlFromZip'
)
