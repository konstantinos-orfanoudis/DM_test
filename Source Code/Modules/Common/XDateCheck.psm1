<#
.SYNOPSIS
  Shared helpers for XDateUpdated freshness checking across all module parsers.

.DESCRIPTION
  Provides two functions:
    Get-ChangeLabelCreationDate  - extracts the DialogTag XDateInserted from a TagData XML file.
    Confirm-ExportIfStale        - queries the live DB for an object's current XDateUpdated,
                                   compares it against the label creation date, and prompts
                                   the user y/n when the DB record is newer than the label.
#>

function Get-ChangeLabelCreationDate {
<#
.SYNOPSIS
  Reads the TagData XML and returns the creation date of the change label (DialogTag.XDateInserted).

.PARAMETER ZipPath
  Path to the TagData XML file.

.OUTPUTS
  [datetime] in UTC, or $null if the date cannot be found or parsed.
#>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$ZipPath
  )

  if (-not (Test-Path -LiteralPath $ZipPath)) {
    Write-Warning "XDateCheck: file not found '$ZipPath' — freshness check will be skipped."
    return $null
  }

  $settings = New-Object System.Xml.XmlReaderSettings
  $settings.DtdProcessing = [System.Xml.DtdProcessing]::Ignore
  $settings.XmlResolver   = $null

  $reader = $null
  try {
    $reader = [System.Xml.XmlReader]::Create($ZipPath, $settings)
    $doc = New-Object System.Xml.XmlDocument
    $doc.XmlResolver = $null
    $doc.Load($reader)
  }
  catch {
    Write-Warning "XDateCheck: failed to load XML from '$ZipPath': $_ — freshness check will be skipped."
    return $null
  }
  finally {
    if ($reader) { $reader.Close() }
  }

  # The DialogTag DbObject is the transport package header; XDateInserted on it is the label creation date.
  $valueNode = $doc.SelectSingleNode(
    "//DbObject[Key/Table[@Name='DialogTag']]/Columns/Column[@Name='XDateInserted']/Value"
  )

  if (-not $valueNode -or [string]::IsNullOrWhiteSpace($valueNode.InnerText)) {
    Write-Warning "XDateCheck: could not find DialogTag/XDateInserted in '$ZipPath' — freshness check will be skipped."
    return $null
  }

  try {
    return [datetime]::Parse(
      $valueNode.InnerText,
      $null,
      [System.Globalization.DateTimeStyles]::RoundtripKind
    )
  }
  catch {
    Write-Warning "XDateCheck: could not parse label creation date '$($valueNode.InnerText)': $_ — freshness check will be skipped."
    return $null
  }
}

function Get-ChangeLabelCreationDateFromDoc {
<#
.SYNOPSIS
  Same as Get-ChangeLabelCreationDate but accepts an already-parsed XmlDocument.
  Used by parsers that have already loaded the XML (avoids a second file read).

.PARAMETER Doc
  An already-loaded System.Xml.XmlDocument for the TagData XML.

.OUTPUTS
  [datetime] in UTC, or $null if not found.
#>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [System.Xml.XmlDocument]$Doc
  )

  $valueNode = $Doc.SelectSingleNode(
    "//DbObject[Key/Table[@Name='DialogTag']]/Columns/Column[@Name='XDateInserted']/Value"
  )

  if (-not $valueNode -or [string]::IsNullOrWhiteSpace($valueNode.InnerText)) {
    Write-Warning "XDateCheck: could not find DialogTag/XDateInserted in the parsed document — freshness check will be skipped."
    return $null
  }

  try {
    return [datetime]::Parse(
      $valueNode.InnerText,
      $null,
      [System.Globalization.DateTimeStyles]::RoundtripKind
    )
  }
  catch {
    Write-Warning "XDateCheck: could not parse label creation date '$($valueNode.InnerText)': $_ — freshness check will be skipped."
    return $null
  }
}

function Confirm-ExportIfStale {
<#
.SYNOPSIS
  Queries the live database for an object's current XDateUpdated and, if it is newer
  than the change label creation date, prompts the user for y/n confirmation.

.DESCRIPTION
  Returns $true  → include the object in the export (either it is fresh, or user said 'y').
  Returns $false → skip the object (user said 'n').
  Returns $true  → on any DB error or missing date (safe default: allow export).

.PARAMETER TableName
  The database table to query.

.PARAMETER WhereClause
  Fully pre-built WHERE clause, e.g.:
    Single PK:    "UID_Person = 'abc-123'"
    Composite PK: "UID_Org = 'abc-123' AND UID_Person = 'def-456'"

.PARAMETER LabelDate
  The change label creation date (DialogTag.XDateInserted).

.PARAMETER ObjectDescription
  Human-readable description shown in the warning/prompt.
#>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$TableName,

    [Parameter(Mandatory)]
    [string]$WhereClause,

    [Parameter(Mandatory)]
    [datetime]$LabelDate,

    [string]$ObjectDescription = ""
  )

  # Query the live DB for the object's current XDateUpdated
  $result = $null
  try {
    $s      = Open-QSql
    $wc     = "SELECT XDateUpdated FROM $TableName WHERE $WhereClause"
    $result = Find-QSql $wc -dict
    Close-QSql
  }
  catch {
    Write-Warning "XDateCheck: DB query failed for $TableName WHERE $WhereClause : $_ — object will be exported."
    return $true
  }

  if (-not $result -or -not $result.ContainsKey("XDateUpdated")) {
    # Object not found in DB or column missing — allow export
    return $true
  }

  $dbDateRaw = $result["XDateUpdated"]
  if ([string]::IsNullOrWhiteSpace($dbDateRaw)) { return $true }

  $dbDate = $null
  try {
    $dbDate = [datetime]::Parse(
      $dbDateRaw,
      $null,
      [System.Globalization.DateTimeStyles]::RoundtripKind
    )
  }
  catch {
    Write-Warning "XDateCheck: could not parse XDateUpdated '$dbDateRaw' for $TableName WHERE $WhereClause — object will be exported."
    return $true
  }

  # Object is fresh — no prompt needed
  if ($dbDate -le $LabelDate) { return $true }

  # Object was modified in the DB AFTER the change label was created — prompt user
  $desc = if (-not [string]::IsNullOrWhiteSpace($ObjectDescription)) { $ObjectDescription } else { "$TableName WHERE $WhereClause" }

  Write-Host ""
  Write-Host "  [STALE OBJECT WARNING] $desc" -ForegroundColor Yellow
  Write-Host "    DB XDateUpdated      : $dbDate" -ForegroundColor Yellow
  Write-Host "    Change label created : $LabelDate" -ForegroundColor Yellow
  Write-Host "    The database record was modified AFTER the change label was created." -ForegroundColor Yellow

  $answer = Read-Host "  Export this object anyway? (y/n)"
  return ($answer.Trim() -match '^[yY]')
}

Export-ModuleMember -Function @(
  'Get-ChangeLabelCreationDate',
  'Get-ChangeLabelCreationDateFromDoc',
  'Confirm-ExportIfStale'
)
