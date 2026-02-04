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

  # Generate timestamp prefix
  $timestamp = Get-Date -Format "000_yyyy_MM_dd"

  # Build key map: TableName -> PKName
  $keyMap = [ordered]@{}
  foreach ($obj in $DbObjects) {
    if (-not $keyMap.Contains($obj.TableName) -and -not [string]::IsNullOrWhiteSpace($obj.PkName)) {
      $keyMap[$obj.TableName] = $obj.PkName
    }
  }

  # Build column schema: TableName -> ordered list of unique column names
  $columnsByTable = [ordered]@{}
  foreach ($obj in $DbObjects) {
    if ([string]::IsNullOrWhiteSpace($obj.TableName)) { continue }
    
    if (-not $columnsByTable.Contains($obj.TableName)) {
      $columnsByTable[$obj.TableName] = [ordered]@{}
    }
    
    # Add PK first
    if (-not [string]::IsNullOrWhiteSpace($obj.PkName)) {
      $columnsByTable[$obj.TableName][$obj.PkName] = $true
    }
    
    # Add other columns in order
    foreach ($col in $obj.Columns) {
      if (-not [string]::IsNullOrWhiteSpace($col.Name)) {
        $columnsByTable[$obj.TableName][$col.Name] = $true
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

  foreach ($tableName in $columnsByTable.Keys) {
    # Paths for this table with timestamp
    $tableXmlPath = Join-Path $OutPath "${timestamp}_${tableName}.xml"
    $tableCsvPath = Join-Path $OutPath "${timestamp}_${tableName}.csv"

    # Get column order for this table
    $columnOrder = @($columnsByTable[$tableName].Keys)
    $pkName = $keyMap[$tableName]

    #region Create Schema-Only XML for this table

    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Indent = $true
    $settings.OmitXmlDeclaration = $false
    $settings.Encoding = New-Object System.Text.UTF8Encoding($false)

    $sw = New-Object System.IO.StringWriter
    $xw = [System.Xml.XmlWriter]::Create($sw, $settings)

    try {
      $xw.WriteStartDocument()

      # <Objects> (no namespace for CSV mode)
      $xw.WriteStartElement("Objects")

      # <Keys>
      $xw.WriteStartElement("Keys")
      $xw.WriteStartElement($tableName)
      $xw.WriteString([string]$pkName)
      $xw.WriteEndElement()
      $xw.WriteEndElement() # </Keys>

      # Write schema with placeholders for this table
      $xw.WriteStartElement($tableName)
      
      # Write each column with @ColumnName@ placeholder
      foreach ($colName in $columnOrder) {
        $xw.WriteStartElement($colName)
        $xw.WriteString("@$colName@")
        $xw.WriteEndElement()
      }
      
      $xw.WriteEndElement() # </TableName>

      $xw.WriteEndElement() # </Objects>
      $xw.WriteEndDocument()
    }
    finally {
      $xw.Flush()
      $xw.Close()
    }

    $xmlString = $sw.ToString()

    # Write XML to file
    $xmlString | Out-File -LiteralPath $tableXmlPath -Encoding utf8

    Write-Host "Wrote schema XML: $tableXmlPath"

    if ($PreviewXml) {
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
        
        foreach ($colName in $columnOrder) {
          $value = ""
          
          # Check if it's the PK
          if ($colName -eq $obj.PkName) {
            $value = $obj.PkValue
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
    
    # Write CSV to file
    $csvRows | Out-File -LiteralPath $tableCsvPath -Encoding utf8
    
    $rowCount = if ($objectsByTable.Contains($tableName)) { $objectsByTable[$tableName].Count } else { 0 }
    Write-Host "Wrote data CSV: $tableCsvPath (Rows: $rowCount)"

    #endregion
  }

  #endregion

  return "Created $($columnsByTable.Count) XML/CSV file pair(s)"
}

# Export module members
Export-ModuleMember -Function @(
  'Export-ToCsvMode'
)
