<#
.SYNOPSIS
  CSV Exporter Module - Exports DbObjects to schema XML and CSV files per table.
 
.DESCRIPTION
  This module provides functions to export DbObjects to separate XML schema files
  and CSV data files for each table.
#>
 
function ConvertTo-CsvValue {
  <#
  .SYNOPSIS
    Converts a value to CSV-safe format with proper escaping.
 
  .PARAMETER Value
    Value to convert.
 
  .OUTPUTS
    CSV-escaped string.
  #>
  param([Parameter()][string]$Value)
 
  if ([string]::IsNullOrEmpty($Value)) {
    return ""
  }
 
  # If value contains comma, quote, or newline, wrap in quotes and escape internal quotes
  if ($Value -match '[,"\r\n]') {
    $escaped = $Value -replace '"', '""'
    return "`"$escaped`""
  }
 
  return $Value
}
 
function Export-ToCsvMode {
  <#
  .SYNOPSIS
    Exports DbObjects to separate schema-only XML files and CSV files per table.
 
  .PARAMETER DbObjects
    Array of DbObjects to export.
 
  .PARAMETER OutPath
    Output directory path.
 
  .PARAMETER PreviewXml
    If set, prints the generated XML to the console.
 
  .OUTPUTS
    Summary string of files created.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][object[]]$DbObjects,
    [Parameter(Mandatory)][string]$OutPath,
    [switch]$PreviewXml
  )
 
 
 
  # Build key map: TableName -> PKName (raw, may be composite with spaces)
  $keyMap = [ordered]@{}
  
  foreach ($obj in $DbObjects) {
    if (-not $keyMap.Contains($obj.TableName) -and -not [string]::IsNullOrWhiteSpace($obj.PkName)) {
      $keyMap[$obj.TableName] = $obj.PkName
    }
  }
 
  # Build column schema: TableName -> ordered list of column objects with metadata
  # Columns are added in parse order (PKs are now included in obj.Columns at their original position)
  $columnsByTable = [ordered]@{}
  
  foreach ($obj in $DbObjects) {
    if ([string]::IsNullOrWhiteSpace($obj.TableName)) { continue }
   
    if (-not $columnsByTable.Contains($obj.TableName)) {
      $columnsByTable[$obj.TableName] = [ordered]@{}
    }

    # Add columns in parse order (first object seen determines the order for each table)
    
    foreach ($col in $obj.Columns) {
      if (-not [string]::IsNullOrWhiteSpace($col.Name)) {
        if (-not $columnsByTable[$obj.TableName].Contains($col.Name)) {
          $columnsByTable[$obj.TableName][$col.Name] = [pscustomobject]@{
            Name = $col.Name
            IsForeignKey = $col.IsForeignKey
            FkTableName = if ($col.IsForeignKey) { $col.FkTableName } else { $null }
            FkColumnName = if ($col.IsForeignKey) { $col.FkColumnName } else { $null }
          }
        }
        elseif ($col.IsForeignKey) {
          # Update existing entry with FK metadata
          $columnsByTable[$obj.TableName][$col.Name].IsForeignKey = $col.IsForeignKey
          $columnsByTable[$obj.TableName][$col.Name].FkTableName = $col.FkTableName
          $columnsByTable[$obj.TableName][$col.Name].FkColumnName = $col.FkColumnName
        }
      }
    }

    # Safety: ensure any PK from PkName that wasn't in Columns still gets added
    if ($obj.PkName) {
      $pkParts = @($obj.PkName)
      foreach ($pkPart in $pkParts) {
        if (-not [string]::IsNullOrWhiteSpace($pkPart) -and
            -not $columnsByTable[$obj.TableName].Contains($pkPart)) {
          $columnsByTable[$obj.TableName][$pkPart] = [pscustomobject]@{
            Name = $pkPart
            IsForeignKey = $false
            FkTableName = $null
            FkColumnName = $null
          }
        }
      }
    }
  }
 
  # Ensure output directory exists
  if (-not (Test-Path -LiteralPath $OutPath)) {
    New-Item -ItemType Directory -Path $OutPath -Force | Out-Null
  }
 
  # Group objects by table
  $objectsByTable = @{}
  foreach ($obj in $DbObjects) {
    if ([string]::IsNullOrWhiteSpace($obj.TableName)) { continue }
   
    if (-not $objectsByTable.Contains($obj.TableName)) {
      $objectsByTable[$obj.TableName] = New-Object System.Collections.Generic.List[object]
    }
    $objectsByTable[$obj.TableName].Add($obj)
  }
 
  #region Create Separate XML and CSV Per Table
 $counter = 0
  foreach ($tableName in $columnsByTable.Keys) {
    # Paths for this table with timestamp
    $tableXmlPath = Join-Path $OutPath "Template_${tableName}.xml"
    $fileName = ('{0:D3}-{1}' -f ($counter + 1), $tableName)
    $tableCsvPath = Join-Path $OutPath "$fileName.csv"
    $counter++
 



    # Get column order for this table
    $columnOrder = @($columnsByTable[$tableName].Keys)
    $pkName = $keyMap[$tableName]
    # Split composite PK into individual names for matching
    $pkParts = @(if (-not [string]::IsNullOrWhiteSpace($pkName)) { $pkName -split '\s+' } else { @() })
 
    #region Create Schema-Only XML for this table
 
    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Indent = $true
    $settings.OmitXmlDeclaration = $false
    $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
 
    $ms = New-Object System.IO.MemoryStream
    $streamWriter = New-Object System.IO.StreamWriter($ms, (New-Object System.Text.UTF8Encoding($false)))
    $xw = [System.Xml.XmlWriter]::Create($streamWriter, $settings)
 
    try {
      $xw.WriteStartDocument()
 
      # <Objects> (no namespace for CSV mode)
      $xw.WriteStartElement("Objects")
 
      # <Keys> - write each PK part as a separate element
      $xw.WriteStartElement("Keys")
      $pkPartsForKeys = @(if (-not [string]::IsNullOrWhiteSpace($pkName)) { $pkName -split '\s+' } else { @() })
      foreach ($pkPart in $pkPartsForKeys) {
        $xw.WriteStartElement($tableName)
        $xw.WriteString([string]$pkPart)
        $xw.WriteEndElement()
      }
      $xw.WriteEndElement() # </Keys>
 
      # Write schema with placeholders for this table
      $xw.WriteStartElement($tableName)
     
      # Write each column with appropriate placeholder structure
      foreach ($colName in $columnOrder) {
        $colMeta = $columnsByTable[$tableName][$colName]
       
        $xw.WriteStartElement($colName)
       
        # Check if this is a foreign key
        if ($colMeta.IsForeignKey -and
            -not [string]::IsNullOrWhiteSpace($colMeta.FkTableName) -and
            -not [string]::IsNullOrWhiteSpace($colMeta.FkColumnName)) {
         
          # Write nested structure for FK: <ColumnName><FkTable><FkColumn>@ColumnName@</FkColumn></FkTable></ColumnName>
          $xw.WriteStartElement($colMeta.FkTableName)
          $xw.WriteStartElement($colMeta.FkColumnName)
          $xw.WriteString("@$colName@")  # Placeholder is the original column name
          $xw.WriteEndElement() # </FkColumnName>
          $xw.WriteEndElement() # </FkTableName>
        }
        else {
          # Normal column - just placeholder
          $xw.WriteString("@$colName@")
        }
       
        $xw.WriteEndElement() # </ColumnName>
      }
     
      $xw.WriteEndElement() # </TableName>
 
      $xw.WriteEndElement() # </Objects>
      $xw.WriteEndDocument()
    }
    finally {
      $xw.Flush()
      $xw.Close()
    }
 
    $xmlString = [System.Text.Encoding]::UTF8.GetString($ms.ToArray())
    $streamWriter.Dispose()
    $ms.Dispose()
 
    # Write XML to file (UTF-8 without BOM)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($tableXmlPath, $xmlString, $utf8NoBom)
 
    Write-Host "Wrote schema XML: $tableXmlPath"
    $Logger = Get-logger
    $Logger.info("Wrote schema XML: $tableXmlPath")
 
    if ($PreviewXml) {
      $Logger = Get-Logger
      $Logger.info("--- XML Preview: $tableName ---")
      $Logger.info($xmlString)
      $Logger.info("--- End Preview ---")
      Write-Host ""
      Write-Host "--- XML Preview: $tableName ---"
      Write-Host $xmlString
      Write-Host "--- End Preview ---"
      Write-Host ""
    }
 
    #endregion
 
    #region Create CSV for this table
 
    # Build CSV content
    $csvRows = New-Object System.Collections.Generic.List[string]
   
    # Header row
    $csvRows.Add($columnOrder -join ',')
   
    # Data rows (if objects exist for this table)
    if ($objectsByTable.Contains($tableName)) {
      foreach ($obj in $objectsByTable[$tableName]) {
        $rowValues = New-Object System.Collections.Generic.List[string]
        
        # Split this object's PK into parts for matching
        $objPkParts = @(if (-not [string]::IsNullOrWhiteSpace($obj.PkName)) { $obj.PkName -split '\s+' } else { @() })
        # Split PK values similarly (space-separated composite values)
        $objPkValues = @(if (-not [string]::IsNullOrWhiteSpace($obj.PkValue)) { $obj.PkValue -split '\s+' } else { @() })
        # Build a lookup: PK part name -> PK part value
        $pkValueMap = @{}
        for ($i = 0; $i -lt $objPkParts.Count; $i++) {
          if ($i -lt $objPkValues.Count) {
            $pkValueMap[$objPkParts[$i]] = $objPkValues[$i]
          }
        }
       
        foreach ($colName in $columnOrder) {
          $value = ""
         
          # Check if it's one of the PK parts
          if ($pkValueMap.ContainsKey($colName)) {
            $value = $pkValueMap[$colName]
          }
          else {
            # Find in columns array
            $col = $obj.Columns | Where-Object { $_.Name -eq $colName } | Select-Object -First 1
            if ($col) {
              $value = $col.Value
            }
          }
         
          # Add CSV-escaped value
          $rowValues.Add((ConvertTo-CsvValue -Value $value))
        }
       
        $csvRows.Add($rowValues -join ',')
      }
    }
   
    # Write CSV to file (UTF-8 without BOM)
    $csvContent = $csvRows -join "`r`n"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($tableCsvPath, $csvContent, $utf8NoBom)
   
    $rowCount = if ($objectsByTable.Contains($tableName)) { $objectsByTable[$tableName].Count } else { 0 }
    Write-Host "Wrote data CSV: $tableCsvPath (Rows: $rowCount)"
    $Logger = Get-logger
    $Logger.info("Wrote data CSV: $tableCsvPath (Rows: $rowCount)")
 
    #endregion
  }
 
  #endregion
 
  return "Created $($columnsByTable.Count) XML/CSV file pair(s)"
}
 
# Export module members
Export-ModuleMember -Function @(
  'Export-ToCsvMode'
)
