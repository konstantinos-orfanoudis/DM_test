function Resolve-TagDataXmlFromZip {
  <#
  .SYNOPSIS
    Extracts a ZIP file and returns all XML files found under TagTransport subdirectories.
  
  .DESCRIPTION
    Searches for a 'TagTransport' folder inside the ZIP, then returns all TagData.xml files
    found in the immediate child directories of TagTransport (e.g., TagTransport/case1/TagData.xml).
    Does NOT search recursively - only looks in direct child folders.
    Only extracts files named 'TagData.xml', ignoring other XML files like Container_*.xml.
  
  .PARAMETER ZipPath
    Path to the ZIP file to extract.
  
  .OUTPUTS
    Array of PSCustomObjects with TempDir, XmlFilePath, and ChildDir properties.
  
  .EXAMPLE
    $xmlFiles = Resolve-TagDataXmlFromZip -ZipPath "C:\data\export.zip"
    foreach ($file in $xmlFiles) {
      Write-Host "Processing: $($file.XmlFilePath)"
    }
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ZipPath
  )

  # Validate input
  if (-not (Test-Path -LiteralPath $ZipPath)) {
    throw "ZIP file not found: $ZipPath"
  }

  if ([System.IO.Path]::GetExtension($ZipPath) -ne ".zip") {
    throw "Input -ZipPath must be a .zip file. Got: $ZipPath"
  }

  # Create unique temp directory
  $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("TagTransport_" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $tempDir | Out-Null

  try {
    # Extract the ZIP file
    Write-Verbose "Extracting ZIP to: $tempDir"
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $tempDir -Force

    # Find the TagTransport directory
    $tagTransportDir = Get-ChildItem -LiteralPath $tempDir -Directory -Recurse |
      Where-Object { $_.Name -eq "TagTransport" } |
      Select-Object -First 1

    if (-not $tagTransportDir) {
      throw "Could not find a 'TagTransport' folder inside the ZIP: $ZipPath"
    }

    Write-Verbose "Found TagTransport directory: $($tagTransportDir.FullName)"

    # Get immediate child directories of TagTransport (e.g., case1, case2)
    $childDirs = Get-ChildItem -LiteralPath $tagTransportDir.FullName -Directory

    if (-not $childDirs -or $childDirs.Count -eq 0) {
      throw "No child directories found under TagTransport: $($tagTransportDir.FullName)"
    }

    Write-Verbose "Found $($childDirs.Count) child director(ies) under TagTransport"

    # Build result array
    $result = [System.Collections.ArrayList]::new()
    
    # For each child directory, get XML files (only in that directory, not recursively)
    foreach ($childDir in $childDirs) {
      Write-Verbose "  Checking directory: $($childDir.Name)"
      
      # Only get TagData.xml files directly in this child directory
      $xmlFiles = Get-ChildItem -LiteralPath $childDir.FullName -File -Filter "TagData.xml" -ErrorAction SilentlyContinue
      
      if ($xmlFiles) {
        foreach ($xmlFile in $xmlFiles) {
          # Double-check that this file is actually under the TagTransport path
          if ($xmlFile.FullName.StartsWith($tagTransportDir.FullName, [StringComparison]::OrdinalIgnoreCase)) {
            Write-Verbose "    - Found: $($xmlFile.Name)"
            
            [void]$result.Add([pscustomobject]@{
              TempDir     = $tempDir
              XmlFilePath = $xmlFile.FullName
              ChildDir    = $childDir.Name
              TranspName = [System.IO.Path]::GetFileNameWithoutExtension($ZipPath)
              
            })
          }         
        }
      }
    }

    if ($result.Count -eq 0) {
      throw "No XML files found in child directories of TagTransport: $($tagTransportDir.FullName)"
    }

    Write-Host "Found $($result.Count) XML file(s) in child directories of TagTransport" -ForegroundColor Cyan

    return $result
  }
  catch {
    # Clean up temp directory on error
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
