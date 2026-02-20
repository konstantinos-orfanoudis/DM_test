<#
.SYNOPSIS
  Shared helpers for XDateUpdated freshness checking across all module parsers.

.DESCRIPTION
  Compares each object's XDateUpdated stored in the transport ZIP against the current
  XDateUpdated in the live database. When the DB record is newer, shows a WinForms
  popup with Export / Abort buttons.

  If Abort is clicked and ReportOnDenial is enabled (default), all subsequent objects
  are still collected but no files are written - only a report is printed.

  Global state (null-guarded so -Force reimports do NOT reset live values):
    $global:XDateCheck_ReportOnDenial      [bool]   default $true
    $global:XDateCheck_StaleAbortTriggered [bool]   default $false
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Global state (initialise only if not already set) ---
if ($null -eq $global:XDateCheck_ReportOnDenial)      { $global:XDateCheck_ReportOnDenial      = $true  }
if ($null -eq $global:XDateCheck_StaleAbortTriggered) { $global:XDateCheck_StaleAbortTriggered = $false }

# ---------------------------------------------------------------------------
# Public helpers for callers (MainPsModule, etc.)
# ---------------------------------------------------------------------------

function Set-XDateCheckConfig {
<#
.SYNOPSIS  Configures the module-level ReportOnDenial flag.
#>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [bool]$ReportOnDenial
  )
  $global:XDateCheck_ReportOnDenial = $ReportOnDenial
}

function Reset-StaleAbortFlag {
<#
.SYNOPSIS  Resets the abort flag - call at the start of each file in the main loop.
#>
  $global:XDateCheck_StaleAbortTriggered = $false
}

function Get-StaleAbortTriggered {
<#
.SYNOPSIS  Returns $true if Abort was clicked on any object in the current file.
#>
  return $global:XDateCheck_StaleAbortTriggered
}

# ---------------------------------------------------------------------------
# Get-XDateUpdatedFromBlock
# ---------------------------------------------------------------------------

function Get-XDateUpdatedFromBlock {
<#
.SYNOPSIS
  Extracts the XDateUpdated value from a decoded XML text block.

.DESCRIPTION
  Tries Op/diff format first (target object date inside decoded ChangeContent),
  then falls back to full-row Column format. Returns $null when not found.

.PARAMETER Block
  A decoded XML string block (DbObject text, Diff text, etc.).
#>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$Block
  )

  # Op / diff format (highest priority - target object date in ChangeContent)
  $m = [regex]::Match(
    $Block,
    '(?is)<Op\b[^>]*\bColumn(?:name|Name)\s*=\s*"XDateUpdated"[^>]*>.*?<Value>\s*([^<\s][^<]*?)\s*</Value>'
  )
  if ($m.Success) { return $m.Groups[1].Value.Trim() }

  # Full-row Column format
  $m = [regex]::Match(
    $Block,
    '(?is)<Column\b[^>]*\bName\s*=\s*"XDateUpdated"[^>]*>.*?<Value>\s*([^<\s][^<]*?)\s*</Value>'
  )
  if ($m.Success) { return $m.Groups[1].Value.Trim() }

  return $null
}

# ---------------------------------------------------------------------------
# Show-StaleObjectDialog  (WinForms popup)
# ---------------------------------------------------------------------------

function Show-StaleObjectDialog {
<#
.SYNOPSIS
  Displays a WinForms warning dialog for a stale transport object.

.OUTPUTS
  "Export" or "Abort"
#>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Description,
    [Parameter(Mandatory)][datetime]$TransportDate,
    [Parameter(Mandatory)][datetime]$DbDate
  )

  $form = New-Object System.Windows.Forms.Form
  $form.Text            = "Stale Object Warning"
  $form.Size            = New-Object System.Drawing.Size(540, 260)
  $form.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterScreen
  $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
  $form.MaximizeBox     = $false
  $form.MinimizeBox     = $false
  $form.TopMost         = $true
  $form.Icon            = [System.Drawing.SystemIcons]::Warning

  $lbl = New-Object System.Windows.Forms.Label
  $lbl.Location  = New-Object System.Drawing.Point(16, 16)
  $lbl.Size      = New-Object System.Drawing.Size(500, 150)
  $lbl.Font      = New-Object System.Drawing.Font("Segoe UI", 9)
  $lbl.Text      = @"
STALE OBJECT DETECTED

Object  : $Description

Transport XDateUpdated : $($TransportDate.ToString("yyyy-MM-dd HH:mm:ss"))
Database  XDateUpdated : $($DbDate.ToString("yyyy-MM-dd HH:mm:ss"))

The database record was modified AFTER the transport was created.
Export this object anyway?
"@
  $form.Controls.Add($lbl)

  $btnExport = New-Object System.Windows.Forms.Button
  $btnExport.Location  = New-Object System.Drawing.Point(320, 185)
  $btnExport.Size      = New-Object System.Drawing.Size(90, 30)
  $btnExport.Text      = "Export"
  $btnExport.BackColor = [System.Drawing.Color]::SteelBlue
  $btnExport.ForeColor = [System.Drawing.Color]::White
  $btnExport.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $btnExport.DialogResult = [System.Windows.Forms.DialogResult]::Yes
  $form.Controls.Add($btnExport)

  $btnAbort = New-Object System.Windows.Forms.Button
  $btnAbort.Location  = New-Object System.Drawing.Point(424, 185)
  $btnAbort.Size      = New-Object System.Drawing.Size(90, 30)
  $btnAbort.Text      = "Abort"
  $btnAbort.BackColor = [System.Drawing.Color]::Firebrick
  $btnAbort.ForeColor = [System.Drawing.Color]::White
  $btnAbort.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $btnAbort.DialogResult = [System.Windows.Forms.DialogResult]::No
  $form.Controls.Add($btnAbort)

  $form.AcceptButton = $btnExport
  $form.CancelButton = $btnAbort

  $result = $form.ShowDialog()
  $form.Dispose()

  if ($result -eq [System.Windows.Forms.DialogResult]::Yes) { return "Export" }
  return "Abort"
}

# ---------------------------------------------------------------------------
# Confirm-ExportIfStale  (main entry point for parsers)
# ---------------------------------------------------------------------------

function Confirm-ExportIfStale {
<#
.SYNOPSIS
  Compares the transport XDateUpdated against the live DB XDateUpdated.
  Shows a popup when the DB is newer; handles abort/report mode globally.

.DESCRIPTION
  Returns $true  -> include the object (fresh, user chose Export, or report mode).
  Returns $false -> skip the object (user chose Abort, ReportOnDenial is off).

.PARAMETER TableName
  Database table to query.

.PARAMETER WhereClause
  Pre-built WHERE clause identifying the object.

.PARAMETER TransportXDateUpdated
  XDateUpdated string extracted from the transport ZIP for this object.
  Pass $null or "" to skip the freshness check (object is always allowed).

.PARAMETER ObjectDescription
  Human-readable label shown in the popup.
#>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$TableName,

    [Parameter(Mandatory)]
    [string]$WhereClause,

    [string]$TransportXDateUpdated = "",

    [string]$ObjectDescription = ""
  )

  # --- Report mode: abort already triggered in this file - include everything ---
  if ($global:XDateCheck_StaleAbortTriggered) { return $true }

  # --- No transport date available - skip check ---
  if ([string]::IsNullOrWhiteSpace($TransportXDateUpdated)) { return $true }

  # --- Parse transport date ---
  $transportDate = $null
  try {
    $transportDate = [datetime]::Parse(
      $TransportXDateUpdated,
      $null,
      [System.Globalization.DateTimeStyles]::RoundtripKind
    )
  }
  catch {
    Write-Warning "XDateCheck: could not parse transport XDateUpdated '$TransportXDateUpdated' for $TableName WHERE $WhereClause - object will be exported."
    return $true
  }

  # --- Query live DB for current XDateUpdated ---
  $result = $null
  try {
    $s      = Open-QSql
    $wc     = "SELECT XDateUpdated FROM $TableName WHERE $WhereClause"
    $result = Find-QSql $wc -dict
    Close-QSql
  }
  catch {
    Write-Warning "XDateCheck: DB query failed for $TableName WHERE $WhereClause : $_ - object will be exported."
    return $true
  }

  if (-not $result -or -not $result.ContainsKey("XDateUpdated")) { return $true }

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
    Write-Warning "XDateCheck: could not parse DB XDateUpdated '$dbDateRaw' for $TableName WHERE $WhereClause - object will be exported."
    return $true
  }

  # --- Fresh: DB not newer than transport ---
  if ($dbDate -le $transportDate) { return $true }

  # --- Stale: show popup ---
  $desc = if (-not [string]::IsNullOrWhiteSpace($ObjectDescription)) { $ObjectDescription } else { "$TableName WHERE $WhereClause" }

  $choice = Show-StaleObjectDialog -Description $desc -TransportDate $transportDate -DbDate $dbDate

  if ($choice -eq "Export") { return $true }

  # Abort chosen
  if ($global:XDateCheck_ReportOnDenial) {
    $global:XDateCheck_StaleAbortTriggered = $true
    Write-Host "  [REPORT MODE ACTIVATED] Abort chosen for: $desc" -ForegroundColor Yellow
    return $true   # still collect the object so it appears in the report
  }

  return $false    # skip this object entirely
}

# ---------------------------------------------------------------------------
Export-ModuleMember -Function @(
  'Set-XDateCheckConfig',
  'Reset-StaleAbortFlag',
  'Get-StaleAbortTriggered',
  'Get-XDateUpdatedFromBlock',
  'Confirm-ExportIfStale'
)
