<#
.SYNOPSIS
  Export ONLY the embedded DbObjects found in Column[@Name='ChangeContent'] to a DM Objects XML file.

.PARAMETER Path
  Path to the outer XML file (e.g., Transport TagData.xml).

.PARAMETER OutXmlPath
  Output XML file path.

.PARAMETER IncludeEmptyValues
  If set, includes columns even when their value is empty. Default: off (matches your prior behavior).

.PARAMETER PreviewXml
  If set, prints the generated XML to the console.

.EXAMPLE
  .\Export-DbObjectsOnly.ps1 -Path "C:\...\TagData.xml" -OutXmlPath "C:\temp\DbObjects.xml" -PreviewXml
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [ValidateNotNullOrEmpty()]
  [string]$Path,

  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$OutXmlPath,

  [Parameter(Mandatory = $false)]
  [switch]$IncludeEmptyValues,

  [Parameter(Mandatory = $false)]
  [switch]$PreviewXml
)

function Remove-InvalidXmlChars {
  param([Parameter(Mandatory)][string]$Text)
  # Strip control chars except TAB/LF/CR
  $Text -replace '[\x00-\x08\x0B\x0C\x0E-\x1F]', ''
}

function Try-LoadEmbeddedXml {
  param([Parameter(Mandatory)][string]$EmbeddedText)

  $t = (Remove-InvalidXmlChars $EmbeddedText).Trim()

  # Attempt 1: parse as-is
  $doc = New-Object System.Xml.XmlDocument
  $doc.XmlResolver = $null
  try {
    $doc.LoadXml($t)
    return $doc
  } catch {
    # Fallback: decode ONCE only if it looks fully escaped
    if ($t -match '^\s*&lt;') {
      $decodedOnce = [System.Net.WebUtility]::HtmlDecode($t)
      $decodedOnce = (Remove-InvalidXmlChars $decodedOnce).Trim()

      $doc2 = New-Object System.Xml.XmlDocument
      $doc2.XmlResolver = $null
      $doc2.LoadXml($decodedOnce)
      return $doc2
    }
    throw
  }
}

function Get-ColumnRawValue {
  param([Parameter(Mandatory)][System.Xml.XmlNode]$ColumnNode)

  $valNode = $ColumnNode.SelectSingleNode("./Value")
  if ($valNode -and -not [string]::IsNullOrWhiteSpace($valNode.InnerText)) {
    return $valNode.InnerText
  }

  $disp = $ColumnNode.Attributes["Display"]
  if ($disp) { return $disp.Value }

  return $null
}

function Get-AllDbObjectsFromChangeContent {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Path,
    [switch]$IncludeEmptyValues
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "File not found: $Path"
  }

  # Load outer XML safely
  $settings = New-Object System.Xml.XmlReaderSettings
  $settings.DtdProcessing = [System.Xml.DtdProcessing]::Ignore
  $settings.XmlResolver   = $null

  $reader = [System.Xml.XmlReader]::Create($Path, $settings)
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

  $all = New-Object System.Collections.Generic.List[object]

  foreach ($cc in $changeColumns) {
    $raw = Get-ColumnRawValue -ColumnNode $cc
    if ([string]::IsNullOrWhiteSpace($raw)) { continue }

    $innerDoc = $null
    try {
      $innerDoc = Try-LoadEmbeddedXml -EmbeddedText $raw
    } catch {
      continue
    }

    $dbObjects = $innerDoc.SelectNodes("/DbObjects/DbObject")
    if (-not $dbObjects -or $dbObjects.Count -eq 0) { continue }

    foreach ($dbo in $dbObjects) {
      $tableNode = $dbo.SelectSingleNode("./Key/Table")
      if (-not $tableNode) { continue }

      $tableName = $tableNode.GetAttribute("Name")

      $pkPropNode = $tableNode.SelectSingleNode("./Prop")
      $pkName  = if ($pkPropNode) { $pkPropNode.GetAttribute("Name") } else { $null }
      $pkValue = if ($pkPropNode) {
        $v = $pkPropNode.SelectSingleNode("./Value")
        if ($v) { $v.InnerText } else { $null }
      } else { $null }

      $obj = [pscustomobject]([ordered]@{
        tableName = $tableName
        pkName    = $pkName
        pkValue   = $pkValue
        columns   = @()   # array of @{ name=; value= }
      })

      $columns = $dbo.SelectNodes("./Columns/Column")
      foreach ($col in $columns) {
        $colName = $col.GetAttribute("Name")

        # Foreign key column if it contains <Key><Table>...
        $fkTableNode = $col.SelectSingleNode("./Key/Table")
        if ($fkTableNode) {
          $refProp = $fkTableNode.SelectSingleNode("./Prop")
          $refVal  = if ($refProp) {
            $rv = $refProp.SelectSingleNode("./Value")
            if ($rv) { $rv.InnerText } else { "" }
          } else { "" }

          if ($IncludeEmptyValues -or -not [string]::IsNullOrWhiteSpace($refVal)) {
            $obj.columns += [pscustomobject]@{ name = $colName; value = $refVal }
          }
          continue
        }

        # Normal column value
        $valNode2 = $col.SelectSingleNode("./Value")
        $valText  = if ($valNode2) { $valNode2.InnerText } else { "" }

        if ($IncludeEmptyValues -or -not [string]::IsNullOrWhiteSpace($valText)) {
          $obj.columns += [pscustomobject]@{ name = $colName; value = $valText }
        }
      }

      $all.Add($obj)
    }
  }

  return $all
}

function Export-DbObjectsToDmObjectsXml {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [object[]]$DbObjects,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$OutXmlPath,

    [switch]$PreviewXml,

    [switch]$CSVMode
  )

  if ($CSVMode) {
    return Export-DbObjectsToDmObjectsXml_CsvMode -DbObjects $DbObjects -OutXmlPath $OutXmlPath -PreviewXml:$PreviewXml
  }

  return Export-DbObjectsToDmObjectsXml_Normal -DbObjects $DbObjects -OutXmlPath $OutXmlPath -PreviewXml:$PreviewXml
}

function Export-DbObjectsToDmObjectsXml_CsvMode {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [object[]]$DbObjects,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$OutXmlPath,

    [switch]$PreviewXml
  )

  # TODO: implement CSV mode later
  throw "CSVMode is not implemented yet."
}

function Export-DbObjectsToDmObjectsXml_Normal {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [object[]]$DbObjects,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$OutXmlPath,

    [switch]$PreviewXml
  )

  # Namespace per your example
  $nsDefault = "http://www.intragen.com/xsd/XmlObjectSchema"
  $nsXsi     = "http://www.w3.org/2001/XMLSchema-instance"

  # Build key map: TableName -> PKName (first seen)
  $keyMap = [ordered]@{}
  foreach ($o in $DbObjects) {
    if (-not $keyMap.Contains($o.tableName) -and -not [string]::IsNullOrWhiteSpace($o.pkName)) {
      $keyMap[$o.tableName] = $o.pkName
    }
  }

  $settings = New-Object System.Xml.XmlWriterSettings
  $settings.Indent = $true
  $settings.OmitXmlDeclaration = $false
  $settings.Encoding = New-Object System.Text.UTF8Encoding($false)  # UTF-8 no BOM

  $dir = Split-Path -Parent $OutXmlPath
  if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }

  $sw = New-Object System.IO.StringWriter
  $xw = [System.Xml.XmlWriter]::Create($sw, $settings)

  $xw.WriteStartDocument()

  # <Objects xmlns="..." xmlns:xsi="...">
  $xw.WriteStartElement("Objects", $nsDefault)
  $xw.WriteAttributeString("xmlns", "xsi", $null, $nsXsi)

  # <Keys>
  $xw.WriteStartElement("Keys", $nsDefault)
  foreach ($k in $keyMap.Keys) {
    $xw.WriteStartElement($k, $nsDefault)
    $xw.WriteString([string]$keyMap[$k])
    $xw.WriteEndElement()
  }
  $xw.WriteEndElement() # </Keys>

  # One element per DbObject: <TableName> ... </TableName>
  foreach ($o in $DbObjects) {
    if ([string]::IsNullOrWhiteSpace($o.tableName)) { continue }

    $xw.WriteStartElement($o.tableName, $nsDefault)

    # PK first
    if (-not [string]::IsNullOrWhiteSpace($o.pkName)) {
      $xw.WriteStartElement($o.pkName, $nsDefault)
      if ($null -ne $o.pkValue) { $xw.WriteString([string]$o.pkValue) }
      $xw.WriteEndElement()
    }

    # Other columns
    foreach ($c in $o.columns) {
      if ([string]::IsNullOrWhiteSpace($c.name)) { continue }

      $xw.WriteStartElement($c.name, $nsDefault)
      if ($null -ne $c.value) { $xw.WriteString([string]$c.value) }
      $xw.WriteEndElement()
    }

    $xw.WriteEndElement() # </TableName>
  }

  $xw.WriteEndElement() # </Objects>
  $xw.WriteEndDocument()
  $xw.Flush()
  $xw.Close()

  $xmlString = $sw.ToString()

  # Write to file
  $xmlString | Out-File -LiteralPath $OutXmlPath -Encoding utf8

  Write-Host "Wrote DBObjects-only XML to: $OutXmlPath" -ForegroundColor Green

  if ($PreviewXml) {
    Write-Host ""
    Write-Host "==================== XML PREVIEW BEGIN ====================" -ForegroundColor Cyan
    Write-Host $xmlString
    Write-Host "===================== XML PREVIEW END =====================" -ForegroundColor Cyan
    Write-Host ""
  }

  return $xmlString
}




function Filter-DbObjectsByAllowedColumns {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][object[]]$DbObjects,
    [Parameter(Mandatory)]$AllowedColumnsByTable  # hashtable or dictionary: tableName -> string[]
  )

  foreach ($o in $DbObjects) {

    # if table not in perms response, keep no columns (or keep all — your choice)
    if (-not $AllowedColumnsByTable.ContainsKey($o.tableName)) {
      $o.columns = @()
      continue
    }

    $allowedSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($c in $AllowedColumnsByTable[$o.tableName]) { [void]$allowedSet.Add($c) }

    $o.columns = @(
      $o.columns | Where-Object { $_.name -and $allowedSet.Contains($_.name) }
    )
  }

  return $DbObjects
}


# ---------------- ENTRY POINT ----------------
# ---------------- ENTRY POINT ----------------
$dbObjects = Get-AllDbObjectsFromChangeContent -Path $Path -IncludeEmptyValues:$IncludeEmptyValues

if (-not $dbObjects -or $dbObjects.Count -eq 0) {
  Write-Host "No embedded DbObjects found inside ChangeContent in: $Path" -ForegroundColor Yellow
  return
}

# --- login session ---
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

$loginUri="http://localhost:8182/imx/login/SupportPlus"
$body = @{ Module="DialogUser"; User="viadmin"; Password="Password.123" } | ConvertTo-Json
Invoke-WebRequest -Uri $loginUri -Method Post -ContentType "application/json" -Body $body -WebSession $session | Out-Null

# --- build tables csv (unique) ---
$tables = ($dbObjects.tableName | Where-Object { $_ } | Sort-Object -Unique) -join ','
$tablesParam = [uri]::EscapeDataString($tables)

# --- call perms endpoint ---
$uri = "http://localhost:8182/SupportPlus/FindColumnsPerms?Tables=$tablesParam"

$headers = @{
  "Accept"             = "application/json"
  "X-Forwarded-For"     = "127.0.0.1"
  "X-Forwarded-Host"    = "localhost:8182"
  "X-Forwarded-Proto"   = "http"
}

$res = Invoke-WebRequest -Uri $uri -Method Get -Headers $headers -WebSession $session -ErrorAction Stop

# --- parse perms JSON (Person -> [..], Org -> [..]) ---
$permsObj = $res.Content | ConvertFrom-Json

# Convert PSCustomObject to hashtable: tableName -> string[]
$allowedByTable = @{}
foreach ($p in $permsObj.PSObject.Properties) {
  $allowedByTable[$p.Name] = @($p.Value)  # force array
}

# --- filter dbObjects columns based on allowed columns ---
$dbObjectsFiltered = Filter-DbObjectsByAllowedColumns -DbObjects $dbObjects -AllowedColumnsByTable $allowedByTable

# --- export filtered objects ---
Export-DbObjectsToDmObjectsXml -DbObjects $dbObjectsFiltered -OutXmlPath $OutXmlPath -PreviewXml:$PreviewXml | Out-Null
