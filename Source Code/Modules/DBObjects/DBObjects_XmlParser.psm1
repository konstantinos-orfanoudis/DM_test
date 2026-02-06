<#
.SYNOPSIS
  XML Parser Module - Handles parsing of TagData XML files and extracting DbObjects.

.DESCRIPTION
  This module provides functions to parse OIM Transport XML files and extract
  embedded DbObject structures from ChangeContent columns.
#>

function Remove-InvalidXmlChars {
  <#
  .SYNOPSIS
    Removes invalid XML characters from text.
  #>
  param([Parameter(Mandatory)][string]$Text)
  
  # Strip control chars except TAB/LF/CR
  $Text -replace '[\x00-\x08\x0B\x0C\x0E-\x1F]', ''
}

function Try-LoadEmbeddedXml {
  <#
  .SYNOPSIS
    Attempts to load embedded XML, handling HTML encoding if necessary.
  #>
  param([Parameter(Mandatory)][string]$EmbeddedText)

  $cleanText = (Remove-InvalidXmlChars $EmbeddedText).Trim()

  # Attempt 1: parse as-is
  $doc = New-Object System.Xml.XmlDocument
  $doc.XmlResolver = $null
  
  try {
    $doc.LoadXml($cleanText)
    return $doc
  }
  catch {
    # Fallback: decode once if it looks HTML-escaped
    if ($cleanText -match '^\s*&lt;') {
      $decoded = [System.Net.WebUtility]::HtmlDecode($cleanText)
      $decoded = (Remove-InvalidXmlChars $decoded).Trim()

      $doc2 = New-Object System.Xml.XmlDocument
      $doc2.XmlResolver = $null
      $doc2.LoadXml($decoded)
      return $doc2
    }
    throw
  }
}

function Get-ColumnValue {
  <#
  .SYNOPSIS
    Extracts value from a Column node, checking Value child or Display attribute.
  #>
  param([Parameter(Mandatory)][System.Xml.XmlNode]$ColumnNode)

  $valNode = $ColumnNode.SelectSingleNode("./Value")
  if ($valNode -and -not [string]::IsNullOrWhiteSpace($valNode.InnerText)) {
    return $valNode.InnerText
  }

  $dispAttr = $ColumnNode.Attributes["Display"]
  if ($dispAttr) { return $dispAttr.Value }

  return $null
}

function Get-AllDbObjectsFromChangeContent {
  <#
  .SYNOPSIS
    Extracts all DbObject structures from ChangeContent columns in the input XML.
  
  .PARAMETER ZipPath
    Path to the TagData XML file.
  
  .PARAMETER IncludeEmptyValues
    If set, includes columns even when their value is empty.
  
  .OUTPUTS
    Array of PSCustomObjects with TableName, PkName, PkValue, and Columns properties.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrWhiteSpace()]
    [string]$ZipPath,
    
    [switch]$IncludeEmptyValues
  )

  if (-not (Test-Path -LiteralPath $ZipPath)) {
    throw "File not found: $ZipPath"
  }

  # Load outer XML safely
  $settings = New-Object System.Xml.XmlReaderSettings
  $settings.DtdProcessing = [System.Xml.DtdProcessing]::Ignore
  $settings.XmlResolver   = $null

  $reader = [System.Xml.XmlReader]::Create($ZipPath, $settings)
  try {
    $outerDoc = New-Object System.Xml.XmlDocument
    $outerDoc.PreserveWhitespace = $false
    $outerDoc.XmlResolver = $null
    $outerDoc.Load($reader)
  }
  finally {
    if ($reader) { $reader.Close() }
  }

  $changeColumns = $outerDoc.SelectNodes("//Column[@Name='ChangeContent']")
  if (-not $changeColumns -or $changeColumns.Count -eq 0) {
    return @()
  }

  $allObjects = New-Object System.Collections.Generic.List[object]

  foreach ($changeCol in $changeColumns) {
    $rawXml = Get-ColumnValue -ColumnNode $changeCol
    if ([string]::IsNullOrWhiteSpace($rawXml)) { continue }

    # Try to parse the embedded XML
    $innerDoc = $null
    try {
      $innerDoc = Try-LoadEmbeddedXml -EmbeddedText $rawXml
    }
    catch {
      $Logger = Get-Logger
      $Logger.Info("Failed to parse embedded XML in ChangeContent: $_")
      Write-Warning "Failed to parse embedded XML in ChangeContent: $_"
      continue
    }

    # Try with wrapper first (<DbObjects><DbObject>...</DbObject></DbObjects>)
    $dbObjects = $innerDoc.SelectNodes("/DbObjects/DbObject")
    
    # If not found, try without wrapper (standalone <DbObject>...</DbObject>)
    if (-not $dbObjects -or $dbObjects.Count -eq 0) {
      $dbObjects = $innerDoc.SelectNodes("/DbObject")
    }
    
    if (-not $dbObjects -or $dbObjects.Count -eq 0) { continue }

    foreach ($dbo in $dbObjects) {
      # Extract table info
      $tableNode = $dbo.SelectSingleNode("./Key/Table")
      if (-not $tableNode) { continue }

      $tableName = $tableNode.GetAttribute("Name")
      if ([string]::IsNullOrWhiteSpace($tableName)) { continue }

      # Extract primary key info
      $pkPropNode = $tableNode.SelectSingleNode("./Prop")
      $pkName  = if ($pkPropNode) { $pkPropNode.GetAttribute("Name") } else { $null }
      $pkValue = if ($pkPropNode) {
        $v = $pkPropNode.SelectSingleNode("./Value")
        if ($v) { $v.InnerText } else { $null }
      } else { $null }

      # Create object structure
      $obj = [pscustomobject]([ordered]@{
        TableName = $tableName
        PkName    = $pkName
        PkValue   = $pkValue
        Columns   = New-Object System.Collections.Generic.List[pscustomobject]
      })

      # Extract column data
      $columns = $dbo.SelectNodes("./Columns/Column")
      foreach ($col in $columns) {
        $colName = $col.GetAttribute("Name")
        if ([string]::IsNullOrWhiteSpace($colName)) { continue }

        # Skip primary key column - it's already written separately
        if (-not [string]::IsNullOrWhiteSpace($pkName) -and $colName -eq $pkName) {
          continue
        }

        # Check if it's a foreign key column
        $fkTableNode = $col.SelectSingleNode("./Key/Table")
        if ($fkTableNode) {
          $fkTableName = $fkTableNode.GetAttribute("Name")
          $refProp = $fkTableNode.SelectSingleNode("./Prop")
          $refPkName = if ($refProp) { $refProp.GetAttribute("Name") } else { $null }
          $refVal  = if ($refProp) {
            $rv = $refProp.SelectSingleNode("./Value")
            if ($rv) { $rv.InnerText } else { "" }
          } else { "" }

          if ($IncludeEmptyValues -or -not [string]::IsNullOrWhiteSpace($refVal)) {
            # Store as foreign key reference with metadata
            $obj.Columns.Add([pscustomobject]@{ 
              Name = $colName
              Value = $refVal
              IsForeignKey = $true
              FkTableName = $fkTableName
              FkColumnName = $refPkName
            })
          }
          continue
        }

        # Normal column value
        $valNode = $col.SelectSingleNode("./Value")
        $valText = if ($valNode) { $valNode.InnerText } else { "" }

        if ($IncludeEmptyValues -or -not [string]::IsNullOrWhiteSpace($valText)) {
          $obj.Columns.Add([pscustomobject]@{ 
            Name = $colName
            Value = $valText
            IsForeignKey = $false
          })
        }
      }

      $allObjects.Add($obj)
    }
  }

  return $allObjects
}

# Export module members
Export-ModuleMember -Function @(
  'Get-AllDbObjectsFromChangeContent'
)