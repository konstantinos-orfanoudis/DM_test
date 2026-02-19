<#
.SYNOPSIS
  XML Parser Module - Handles parsing of TagData XML files and extracting DbObjects.
 
.DESCRIPTION
  This module provides functions to parse OIM Transport XML files and extract
  embedded DbObject structures from ChangeContent columns.
 
.NOTES
  Extended to also capture ChangeContent payloads that are <Diff>...</Diff>.
  In that case, TableName and PkValue are derived from the sibling ObjectKey column.
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
 
  $valNode = $ColumnNode.SelectSingleNode('./Value')
  if ($valNode -and -not [string]::IsNullOrWhiteSpace($valNode.InnerText)) {
    return $valNode.InnerText
  }
 
  $dispAttr = $ColumnNode.Attributes['Display']
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
    $Logger = Get-Logger
    $Logger.info("File not found: $ZipPath")
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
      $Logger.info("Failed to parse embedded XML in ChangeContent: $_")
      Write-Warning "Failed to parse embedded XML in ChangeContent: $_"
      continue
    }
 
    # --- Case 1: DbObject(s) ---
 
    # Try with wrapper first (<DbObjects><DbObject>...</DbObject></DbObjects>)
    $dbObjects = $innerDoc.SelectNodes('/DbObjects/DbObject')
 
    # If not found, try without wrapper (standalone <DbObject>...</DbObject>)
    if (-not $dbObjects -or $dbObjects.Count -eq 0) {
      $dbObjects = $innerDoc.SelectNodes('/DbObject')
    }
 
    if ($dbObjects -and $dbObjects.Count -gt 0) {
      foreach ($dbo in $dbObjects) {
        # Extract table info
        $tableNode = $dbo.SelectSingleNode('./Key/Table')
        if (-not $tableNode) { continue }
 
        $tableName = $tableNode.GetAttribute('Name')
        if ([string]::IsNullOrWhiteSpace($tableName)) { continue }
 
        # Extract primary key info
        $pkPropNode = $tableNode.SelectNodes('./Prop')
        
        $pkName  = if ($pkPropNode) { $pkPropNode.GetAttribute('Name') -split " " } else { $null } 
        $pkValue = if ($pkPropNode) {
          $v = $pkPropNode.SelectSingleNode('./Value')
          if ($v) { $v.InnerText -split " " } else { $null }
        } else { $null }
        
 
        # Read SortOrder from the sibling column on the QBMTaggedChange wrapper row
        $sortOrderCol = $changeCol.ParentNode.SelectSingleNode("./Column[@Name='SortOrder']")
        $sortOrderVal = if ($sortOrderCol) { Get-ColumnValue -ColumnNode $sortOrderCol } else { $null }
        $sortOrderNum = [long]::MaxValue
        if (-not [string]::IsNullOrWhiteSpace($sortOrderVal)) {
          [long]$parsed = 0
          if ([long]::TryParse($sortOrderVal, [ref]$parsed)) { $sortOrderNum = $parsed }
        }

        # Create object structure
        $obj = [pscustomobject]([ordered]@{
          TableName = $tableName
          PkName    = $pkName
          PkValue   = $pkValue
          SortOrder = $sortOrderNum
          Columns   = New-Object System.Collections.Generic.List[pscustomobject]
        })
 
        # Build PK lookup for marking and value override
        $pkNameSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $pkValueMap = @{}
        if ($pkName) {
          $pkNames = @($pkName)
          $pkVals  = @($pkValue)
          for ($i = 0; $i -lt $pkNames.Count; $i++) {
            [void]$pkNameSet.Add($pkNames[$i])
            if ($i -lt $pkVals.Count) { $pkValueMap[$pkNames[$i]] = $pkVals[$i] }
          }
        }

        # Extract column data — PKs are kept in parse order (not skipped)
        $columns = $dbo.SelectNodes('./Columns/Column')
        foreach ($col in $columns) {
          $colName = $col.GetAttribute('Name')
          if ([string]::IsNullOrWhiteSpace($colName)) { continue }
 
          $isPk = $pkNameSet.Contains($colName)
 
          # Check if it's a foreign key column
          $fkTableNode = $col.SelectSingleNode('./Key/Table')
          if ($fkTableNode) {
            write-host "It entered Here 214 Parser 9999999999999999999999999"
            $fkTableName = $fkTableNode.GetAttribute('Name')
            $refProp = $fkTableNode.SelectSingleNode('./Prop')
            $refPkName = if ($refProp) { $refProp.GetAttribute('Name') } else { $null }
            $refVal  = if ($refProp) {
              $rv = $refProp.SelectSingleNode('./Value')
              if ($rv) { $rv.InnerText } else { '' }
            } else { '' }
write-host "refprop=$refProp refpkname= $refPkName  refVal= $refVal line 222 "
            # PK columns are always included; other FKs respect IncludeEmptyValues
            if ($isPk -or $IncludeEmptyValues -or -not [string]::IsNullOrWhiteSpace($refVal)) {
              # Use authoritative PkValue for PK columns
              $finalVal = if ($isPk -and $pkValueMap.ContainsKey($colName)) { $pkValueMap[$colName] } else { $refVal }
              $obj.Columns.Add([pscustomobject]@{
                Name         = $colName
                Value        = $finalVal
                IsForeignKey = $true
                IsPrimaryKey = $isPk
                FkTableName  = $fkTableName
                FkColumnName = $refPkName
              })
              # write-host "Name         = $colName
              #             Value        = $finalVal
              #             IsForeignKey = $true
              #             IsPrimaryKey = $isPk
              #             FkTableName  = $fkTableName
              #             FkColumnName = $refPkName"
            }

            continue
          }

          # Normal column value
          $valNode = $col.SelectSingleNode('./Value')
          $valText = if ($valNode) { $valNode.InnerText } else { '' }

          # PK columns are always included; other columns respect IncludeEmptyValues
          if ($isPk -or $IncludeEmptyValues -or -not [string]::IsNullOrWhiteSpace($valText)) {
            if (-not $fkTableNode) {
                # Use authoritative PkValue for PK columns
                $finalVal = if ($isPk -and $pkValueMap.ContainsKey($colName)) { $pkValueMap[$colName] } else { $valText }
                $obj.Columns.Add([pscustomobject]@{
                  Name         = $colName
                  Value        = $finalVal
                  IsForeignKey = $false
                  IsPrimaryKey = $isPk
                })
                write-host " Name         = $colName
                  Value        = $finalVal
                  IsForeignKey = $false
                  IsPrimaryKey = $isPk"
            }
          }
        }

        $allObjects.Add($obj)
      }
 
      continue
    }
 
    # --- Case 2 (NEW): Diff payload in ChangeContent ---
 
    $diffRoot = $innerDoc.SelectSingleNode('/Diff')
    if (-not $diffRoot) {
      # Not a DbObject(s) and not Diff => nothing to extract
      continue
    }
 
    # Sibling ObjectKey column is on the same parent row
    $objectKeyCol = $changeCol.ParentNode.SelectSingleNode("./Column[@Name='ObjectKey']")
    $objectKeyRaw = if ($objectKeyCol) { Get-ColumnValue -ColumnNode $objectKeyCol } else { $null }
 
    if ([string]::IsNullOrWhiteSpace($objectKeyRaw)) { continue }
 
    $keyDoc = $null
    try {
      $keyDoc = Try-LoadEmbeddedXml -EmbeddedText $objectKeyRaw
    }
    catch {
      $Logger = Get-Logger
      $Logger.info("Failed to parse embedded XML in ObjectKey: $_")
      Write-Warning "Failed to parse embedded XML in ObjectKey: $_"
      continue
    }
 
    $tNode = $keyDoc.SelectSingleNode('/Key/T')
    $pNode = $keyDoc.SelectSingleNode('/Key/P')
 
    $tableName = if ($tNode) { $tNode.InnerText.Trim() } else { $null }
    $pkValue   = if ($pNode) { $pNode.InnerText.Trim() } else { $null }
 
    if ([string]::IsNullOrWhiteSpace($tableName)) 
    { continue }

    $s = Open-QSql
    $wc = "SELECT  ColumnName 
           FROM DialogColumn 
           WHERE 1=1 AND 
            IsPKMember = 1 AND 
            UID_DialogTable IN 
              (
              SELECT UID_DialogTable 
              FROM DialogTable  
              Where TableName = '$tableName' and 
                                TableName not in ('Job', 'JobChain', 'JobEventGen', 'JobRunParameter', 'DialogColumn','DialogScript'))"                                                                                                                             
    $pr = Find-QSql $wc -dict
    if ($pr) {
      $pkcolumnName = $pr["ColumnName"]
    }
    else {return New-Object System.Collections.Generic.List[object]}
    Close-QSql

    # Read SortOrder from the sibling column on the wrapper row
    $sortOrderCol = $changeCol.ParentNode.SelectSingleNode("./Column[@Name='SortOrder']")
    $sortOrderVal = if ($sortOrderCol) { Get-ColumnValue -ColumnNode $sortOrderCol } else { $null }
    $sortOrderNum = [long]::MaxValue
    if (-not [string]::IsNullOrWhiteSpace($sortOrderVal)) {
      [long]$parsed = 0
      if ([long]::TryParse($sortOrderVal, [ref]$parsed)) { $sortOrderNum = $parsed }
    }

    # Create object structure (PkName is not present in ObjectKey; leave null)
    $diffObj = [pscustomobject]([ordered]@{
      TableName = $tableName
      PkName    = $pkcolumnName
      PkValue   = $pkValue
      SortOrder = $sortOrderNum
      Columns   = New-Object System.Collections.Generic.List[pscustomobject]
    })
 
    # Convert Diff Ops into columns
    $ops = $diffRoot.SelectNodes('./Op')
    foreach ($op in $ops) {
      $colName = $op.GetAttribute('Columnname')
      if ([string]::IsNullOrWhiteSpace($colName)) { continue }
 
      $newValNode = $op.SelectSingleNode('./Value')
      $oldValNode = $op.SelectSingleNode('./OldValue')
 
      $newVal = if ($newValNode) { $newValNode.InnerText } else { $null }
      $oldVal = if ($oldValNode) { $oldValNode.InnerText } else { $null }
 
      if ($IncludeEmptyValues -or -not [string]::IsNullOrWhiteSpace($newVal) -or -not [string]::IsNullOrWhiteSpace($oldVal)) {
        $diffObj.Columns.Add([pscustomobject]@{
          Name         = $colName
          Value        = $newVal
          OldValue     = $oldVal
          IsDiffOp     = $true
          IsForeignKey = $false
          IsPrimaryKey = $false
        })
      }
    }
    $allObjects.Add($diffObj)
  }
  return $allObjects

}

function Get-ForeignKeyMetadataPsModule {
  <#
  .SYNOPSIS
    Retrieves foreign key column metadata for specified tables from OIM connection.
    
  .DESCRIPTION
    Uses $connection.Tables.ForeignKeys.ColumnRelations to discover which columns
    in each table are foreign keys, and what parent table/column they reference.
    This is used to enrich parsed DbObjects where the XML may not contain the
    Key/Table FK structure (e.g., when FK value is empty).
  
  .PARAMETER Session
    Authenticated session from Connect-OimPSModule.
  
  .PARAMETER Tables
    Array of table names to query FK metadata for.
  
  .OUTPUTS
    Hashtable: TableName -> Hashtable: ColumnName -> PSCustomObject{FkTableName, FkColumnName}
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [Object]$Session,

    [Parameter(Mandatory)]
    [string[]]$Tables
  )

  try {
    $connection = $Session.Connection
    $fkMetaByTable = @{}

    foreach ($tableName in $Tables) {
      $tableObj = $connection.Tables | Where-Object { $_.TableName -eq $tableName }
      if (-not $tableObj) {
        Write-Warning "Table '$tableName' not found in connection metadata - skipping FK discovery."
        continue
      }

      $fkMap = @{}
      $foreignKeys = $tableObj.ForeignKeys
      if (-not $foreignKeys) {
        $fkMetaByTable[$tableName] = $fkMap
        continue
      }

      foreach ($fk in $foreignKeys) {
        $columnRelations = $fk.ColumnRelations
        if (-not $columnRelations) { continue }

        foreach ($rel in $columnRelations) {
          # ChildColumn format: "ChildTable.ColumnName" (e.g. "PWODecisionStep.UID_DialogRichMailToDelegat")
          $childCol = [string]$rel.ChildColumn
          # ParentColumn format: "ParentTable.PKColumn" (e.g. "DialogRichMail.UID_DialogRichMail")
          $parentCol = [string]$rel.ParentColumn

          if ([string]::IsNullOrWhiteSpace($childCol) -or [string]::IsNullOrWhiteSpace($parentCol)) { continue }

          $childParts  = $childCol -split '\.'
          $parentParts = $parentCol -split '\.'

          # Extract the column name in our table (child side)
          $colName = if ($childParts.Count -ge 2) { $childParts[1] } else { $childParts[0] }
          # Extract parent table and column names
          $fkTable  = if ($parentParts.Count -ge 2) { $parentParts[0] } else { $null }
          $fkColumn = if ($parentParts.Count -ge 2) { $parentParts[1] } else { $parentParts[0] }

          if (-not [string]::IsNullOrWhiteSpace($colName) -and -not $fkMap.ContainsKey($colName)) {
            $fkMap[$colName] = [pscustomobject]@{
              FkTableName  = $fkTable
              FkColumnName = $fkColumn
            }
          }
        }
      }

      $fkMetaByTable[$tableName] = $fkMap
      Write-Host "  FK metadata for '$tableName': $($fkMap.Count) FK column(s) discovered" -ForegroundColor DarkCyan
    }

    return $fkMetaByTable
  }
  catch {
    $Logger = Get-Logger
    $Logger.info("Failed to retrieve FK metadata: $_")
    throw "Failed to retrieve FK metadata: $_"
  }
}

function Enrich-DbObjectsWithFkMetadata {
  <#
  .SYNOPSIS
    Enriches parsed DbObjects with FK metadata from connection discovery.
    
  .DESCRIPTION
    For columns that were parsed as normal (IsForeignKey=$false) but are actually
    foreign keys according to the connection metadata, this function updates them
    to carry the correct FK structure (IsForeignKey, FkTableName, FkColumnName).
    This handles the case where the XML has no Key/Table child for empty FK columns.
  
  .PARAMETER DbObjects
    Array of parsed DbObjects to enrich.
  
  .PARAMETER FkMetaByTable
    Hashtable from Get-ForeignKeyMetadataPsModule.
  
  .OUTPUTS
    The same DbObjects array, with columns enriched in-place.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][object[]]$DbObjects,
    [Parameter(Mandatory)][hashtable]$FkMetaByTable
  )

  foreach ($obj in $DbObjects) {
    if (-not $FkMetaByTable.ContainsKey($obj.TableName)) { continue }

    $fkMap = $FkMetaByTable[$obj.TableName]

    foreach ($col in $obj.Columns) {
      # Only enrich columns not already marked as FK
      if ($col.IsForeignKey) { continue }

      if ($fkMap.ContainsKey($col.Name)) {
        $meta = $fkMap[$col.Name]
        $col | Add-Member -NotePropertyName 'IsForeignKey' -NotePropertyValue $true -Force
        $col | Add-Member -NotePropertyName 'FkTableName'  -NotePropertyValue $meta.FkTableName -Force
        $col | Add-Member -NotePropertyName 'FkColumnName' -NotePropertyValue $meta.FkColumnName -Force
      }
    }
  }

  return $DbObjects
}

function Sort-DbObjectsBySortOrder {
  <#
  .SYNOPSIS
    Sorts DbObjects by the SortOrder value captured from the QBMTaggedChange wrapper row.

  .DESCRIPTION
    Uses the SortOrder property (ascending) to determine object output order.
    Objects without a SortOrder (Long.MaxValue) are placed at the end.

  .PARAMETER DbObjects
    Array of parsed DbObjects to sort.

  .OUTPUTS
    Sorted array of DbObjects.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][object[]]$DbObjects
  )

  if (-not $DbObjects -or $DbObjects.Count -le 1) { return $DbObjects }

  $sorted = $DbObjects | Sort-Object { $_.SortOrder }

  Write-Host "  Sorted $($sorted.Count) object(s) by SortOrder" -ForegroundColor DarkCyan
  return @($sorted)
}
 
# Export module members
Export-ModuleMember -Function @(
  'Get-AllDbObjectsFromChangeContent',
  'Get-ForeignKeyMetadataPsModule',
  'Enrich-DbObjectsWithFkMetadata',
  'Sort-DbObjectsBySortOrder'
)