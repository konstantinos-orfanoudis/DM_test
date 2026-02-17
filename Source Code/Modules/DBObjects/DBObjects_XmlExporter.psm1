<#
.SYNOPSIS
  XML Exporter Module - Exports DbObjects to standard DM Objects XML format.
 
.DESCRIPTION
  This module provides functions to export DbObjects to XML format with
  schema and data combined in a single file.
#>
 
function Export-ToNormalXml {
  <#
  .SYNOPSIS
    Exports DbObjects to standard XML format with schema and data.
 
  .PARAMETER DbObjects
    Array of DbObjects to export.
 
  .PARAMETER OutPath
    Output directory path.
 
  .PARAMETER PreviewXml
    If set, prints the generated XML to the console.
 
  .OUTPUTS
    XML string content.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][object[]]$DbObjects,
    [Parameter(Mandatory)][string]$OutPath,
    [switch]$PreviewXml
  )
 
  # Generate timestamp prefix
  $timestamp = Get-Date -Format "000_yyyy_MM_dd_HH"
 
  # Namespace per DM Objects schema
  $nsDefault = "http://www.intragen.com/xsd/XmlObjectSchema"
  $nsXsi     = "http://www.w3.org/2001/XMLSchema-instance"
 
  # Build key map: TableName -> PKName
  $keyMap = [ordered]@{}
  foreach ($obj in $DbObjects) {
    if (-not $keyMap.Contains($obj.TableName) -and -not [string]::IsNullOrWhiteSpace($obj.PkName)) {
      $keyMap[$obj.TableName] = $obj.PkName
    }
  }
 
  # Ensure output directory exists
  if (-not (Test-Path -LiteralPath $OutPath)) {
    New-Item -ItemType Directory -Path $OutPath -Force | Out-Null
  }
 
  # Generate output filename with timestamp
  $outFile = Join-Path $OutPath "000-DBObjects_$timestamp.xml"
 
  # Configure XML writer
  $settings = New-Object System.Xml.XmlWriterSettings
  $settings.Indent = $true
  $settings.OmitXmlDeclaration = $false
  $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
 
  $ms = New-Object System.IO.MemoryStream
  $xw = [System.Xml.XmlWriter]::Create($ms, $settings)
 
  try {
    $xw.WriteStartDocument()
 
    # <Objects xmlns="..." xmlns:xsi="...">
    $xw.WriteStartElement("Objects", $nsDefault)
    $xw.WriteAttributeString("xmlns", "xsi", $null, $nsXsi)
 
    # <Keys> - write each PK part separately for composite keys
    $xw.WriteStartElement("Keys", $nsDefault)
    foreach ($tableName in $keyMap.Keys) {
      $pkParts = @($keyMap[$tableName] -split '\s+')
      foreach ($pkPart in $pkParts) {
        $xw.WriteStartElement($tableName, $nsDefault)
        $xw.WriteString([string]$pkPart)
        $xw.WriteEndElement()
      }
    }
    $xw.WriteEndElement() # </Keys>
 
    # Write each DbObject as <TableName>...</TableName>
    foreach ($obj in $DbObjects) {
      if ([string]::IsNullOrWhiteSpace($obj.TableName)) { continue }
 
      $xw.WriteStartElement($obj.TableName, $nsDefault)
 
      # Split composite PK names and values
      $pkParts = @(if (-not [string]::IsNullOrWhiteSpace($obj.PkName)) { $obj.PkName -split '\s+' } else { @() })
      $pkValues = @(if (-not [string]::IsNullOrWhiteSpace($obj.PkValue)) { $obj.PkValue -split '\s+' } else { @() })
      
      # Build set of PK part names for skipping in Columns loop
      $pkPartSet = @{}
      foreach ($p in $pkParts) { $pkPartSet[$p] = $true }

      # Always write PK elements first from PkName/PkValue
      for ($i = 0; $i -lt $pkParts.Count; $i++) {
        $pkPartName = $pkParts[$i]
        $xw.WriteStartElement($pkPartName, $nsDefault)
        if ($i -lt $pkValues.Count -and $null -ne $pkValues[$i]) {
          $xw.WriteString([string]$pkValues[$i])
        }
        $xw.WriteEndElement()
      }

      # Write other columns (skip PK columns to avoid duplicates)
      foreach ($col in $obj.Columns) {
        if ([string]::IsNullOrWhiteSpace($col.Name)) { continue }
        if ($pkPartSet.ContainsKey($col.Name)) { continue }
 
        $xw.WriteStartElement($col.Name, $nsDefault)
       
        # Check if this is a foreign key reference
        if ($col.IsForeignKey -and
            -not [string]::IsNullOrWhiteSpace($col.FkTableName) -and
            -not [string]::IsNullOrWhiteSpace($col.FkColumnName)) {
         
          # Write nested structure: <ColumnName><FkTable><FkColumn>value</FkColumn></FkTable></ColumnName>
          $xw.WriteStartElement($col.FkTableName, $nsDefault)
          $xw.WriteStartElement($col.FkColumnName, $nsDefault)
          if ($null -ne $col.Value) {
            $xw.WriteString([string]$col.Value)
          }
          $xw.WriteEndElement() # </FkColumnName>
          $xw.WriteEndElement() # </FkTableName>
        }
        else {
          # Normal column - just write the value
          if ($null -ne $col.Value) {
            $xw.WriteString([string]$col.Value)
          }
        }
       
        $xw.WriteEndElement() # </ColumnName>
      }
 
      $xw.WriteEndElement() # </TableName>
    }
 
    $xw.WriteEndElement() # </Objects>
    $xw.WriteEndDocument()
  }
  finally {
    $xw.Flush()
    $xw.Close()
  }
 
  $ms.Position = 0
  $sr = New-Object System.IO.StreamReader($ms, (New-Object System.Text.UTF8Encoding($false)))
  $xmlString = $sr.ReadToEnd()
  $sr.Close()
  $ms.Close()
 
  # Write to file (UTF-8 without BOM)
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($outFile, $xmlString, $utf8NoBom)
 
  Write-Host "Wrote XML: $outFile"
  $Logger = Get-Logger
  $Logger.info("Wrote XML: $outFile")
 
  if ($PreviewXml) {
    $Logger = Get-Logger
    $Logger.info("--- XML Preview ---")
    $Logger.info($xmlString)
    $Logger.info("--- End Preview ---")
    Write-Host ""
    Write-Host "--- XML Preview ---"
    Write-Host $xmlString
    Write-Host "--- End Preview ---"
    Write-Host ""
  }
 
  return $xmlString
}
 
# Export module members
Export-ModuleMember -Function @(
  'Export-ToNormalXml'
)
