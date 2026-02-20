Set-StrictMode -Version Latest

Import-Module "$PSScriptRoot\..\Common\XDateCheck.psm1" -Force

function GetAllProcessFromChangeLabel {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrWhiteSpace()]
    [string]$ZipPath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [Object]$Session
  )

  if (-not (Test-Path -LiteralPath $ZipPath)) {
    throw "File not found: $ZipPath"
  }

  # Safe XML load
  $settings = New-Object System.Xml.XmlReaderSettings
  $settings.DtdProcessing = [System.Xml.DtdProcessing]::Ignore
  $settings.XmlResolver   = $null

  $reader = [System.Xml.XmlReader]::Create($ZipPath, $settings)
  try {
    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $false
    $doc.XmlResolver = $null
    $doc.Load($reader)
  }
  finally {
    if ($reader) { $reader.Close() }
  }

  # DbObjects that represent tagged changes
  $taggedChangeDbos = $doc.SelectNodes(
    "//*[local-name()='DbObject'][
        ./*[local-name()='Key']/*[local-name()='Table' and @Name='QBMTaggedChange']
     ]"
  )

  # Extract change label creation date once from the already-parsed doc
  $labelDate = Get-ChangeLabelCreationDateFromDoc -Doc $doc

  $results = New-Object 'System.Collections.Generic.List[object]'
  if (-not $taggedChangeDbos) { return $results }

  # Extract UID_JobChain from Diff text (ChangeContent)
  $reUidJobChain = [regex]::new(
    "(?s)<Op\b[^>]*(?:Columnname|ColumnName)\s*=\s*[""']UID_JobChain[""'][^>]*>.*?<Value>\s*(?<uid>[^<\s]+)\s*</Value>",
    [System.Text.RegularExpressions.RegexOptions]::Singleline
  )

  # Extract <T>...</T> and first <P>...</P> from decoded ObjectKey string
  $reObjectKeyTP = [regex]::new(
    "(?s)<T>\s*(?<t>[^<]+)\s*</T>.*?<P>\s*(?<p>[^<]+)\s*</P>",
    [System.Text.RegularExpressions.RegexOptions]::Singleline
  )

  foreach ($dbo in $taggedChangeDbos) {

    # QBMTaggedChange Key attribute (kept; not used further, but preserves your flow)
    $qbmTable = $dbo.SelectSingleNode("./*[local-name()='Key']/*[local-name()='Table' and @Name='QBMTaggedChange']")
    $taggedChangeKey = if ($qbmTable) { $qbmTable.GetAttribute("Key") } else { $null }
    if ([string]::IsNullOrWhiteSpace($taggedChangeKey)) { continue }

    $found = $false

    # 1) Try: JobChain UID from ObjectKey column (ObjectKey is encoded text)
    $okCol = $dbo.SelectSingleNode(".//*[local-name()='Column' and @Name='ObjectKey']")
    if ($okCol) {
      $okRaw = $okCol.GetAttribute("Display")
      if ([string]::IsNullOrWhiteSpace($okRaw)) {
        $v = $okCol.SelectSingleNode("./*[local-name()='Value']")
        if ($v) { $okRaw = $v.InnerText }
      }

      if (-not [string]::IsNullOrWhiteSpace($okRaw)) {
        $okDecoded = $okRaw
        for ($i = 0; $i -lt 3; $i++) {
          $okDecoded = [System.Net.WebUtility]::HtmlDecode($okDecoded)
        }

        $mOk = $reObjectKeyTP.Match($okDecoded)
        if ($mOk.Success) {
          $objType = $mOk.Groups["t"].Value.Trim()
          $objUid  = $mOk.Groups["p"].Value.Trim()

          if ($objType -match '(?i)JobChain' -and -not [string]::IsNullOrWhiteSpace($objUid)) {

            $s = Open-QSql
            $wc = "select Name, UID_DialogTable, XDateUpdated from JobChain where UID_JobChain = '$objUid'"
            $pr = Find-QSql $wc -dict
            Close-QSql

            if ($pr -and $pr.ContainsKey("UID_DialogTable") -and $pr["UID_DialogTable"]) {
              $uid_table = $pr["UID_DialogTable"]
              $processName = $pr["Name"]

              # --- XDateUpdated freshness check (Path 1) ---
              if ($null -ne $labelDate) {
                $dbDateRaw = $pr["XDateUpdated"]
                if (-not [string]::IsNullOrWhiteSpace($dbDateRaw)) {
                  $allow = Confirm-ExportIfStale -TableName 'JobChain' `
                             -WhereClause "UID_JobChain = '$objUid'" `
                             -LabelDate $labelDate `
                             -ObjectDescription "JobChain '$processName' (UID_JobChain = $objUid)"
                  if (-not $allow) { continue }
                }
              }

              $s = Open-QSql
              $wc = "select TableName from DialogTable where UID_DialogTable = '$uid_table'"
              $t = Find-QSql $wc -dict
              Close-QSql

              $TableName = $t["TableName"]

              [void]$results.Add([pscustomobject]@{
                TableName = $TableName
                Name      = $processName
              })

              $found = $true
            }
          }
        }
      }
    }

    # 2) Fallback: UID_JobChain from ChangeContent Diff (e.g., JobEventGen rows)
    if (-not $found) {
      $ccNode = $dbo.SelectSingleNode(".//*[local-name()='Column' and @Name='ChangeContent']")
      if ($ccNode) {

        $raw = $null

        # Prefer Display attribute, else Value inner text
        $disp = $ccNode.Attributes["Display"]
        if ($disp -and -not [string]::IsNullOrWhiteSpace($disp.Value)) {
          $raw = $disp.Value
        } else {
          $v = $ccNode.SelectSingleNode("./*[local-name()='Value']")
          if ($v -and -not [string]::IsNullOrWhiteSpace($v.InnerText)) {
            $raw = $v.InnerText
          }
        }

        if (-not [string]::IsNullOrWhiteSpace($raw)) {
          $decoded = $raw
          for ($i=0; $i -lt 3; $i++) { $decoded = [System.Net.WebUtility]::HtmlDecode($decoded) }

          $m = $reUidJobChain.Match($decoded)
          if ($m.Success) {
            $uid = $m.Groups["uid"].Value.Trim()

            $s = Open-QSql
            $wc = "select Name, UID_DialogTable, XDateUpdated from JobChain where UID_JobChain = '$uid'"
            $pr = Find-QSql $wc -dict
            Close-QSql

            if ($pr -and $pr.ContainsKey("UID_DialogTable") -and $pr["UID_DialogTable"]) {
              $uid_table = $pr["UID_DialogTable"]
              $processName = $pr["Name"]

              # --- XDateUpdated freshness check (Path 2 fallback) ---
              if ($null -ne $labelDate) {
                $dbDateRaw = $pr["XDateUpdated"]
                if (-not [string]::IsNullOrWhiteSpace($dbDateRaw)) {
                  $allow = Confirm-ExportIfStale -TableName 'JobChain' `
                             -WhereClause "UID_JobChain = '$uid'" `
                             -LabelDate $labelDate `
                             -ObjectDescription "JobChain '$processName' (UID_JobChain = $uid)"
                  if (-not $allow) { continue }
                }
              }

              $s = Open-QSql
              $wc = "select TableName from DialogTable where UID_DialogTable = '$uid_table'"
              $t = Find-QSql $wc -dict
              Close-QSql

              $TableName = $t["TableName"]

              [void]$results.Add([pscustomobject]@{
                TableName = $TableName
                Name      = $processName
              })
            }
          }
        }
      }
    }
  }

  # Deduplicate by TableName+Name
  $uniqueProcesses = @{}
  foreach ($result in $results) {
    $key = "$($result.TableName):$($result.Name)"
    if (-not $uniqueProcesses.ContainsKey($key)) {
      $uniqueProcesses[$key] = $result
    }
  }

  $finalResults = New-Object System.Collections.Generic.List[object]
  foreach ($proc in $uniqueProcesses.Values) {
    [void]$finalResults.Add($proc)
  }

  return $finalResults
}

Export-ModuleMember -Function GetAllProcessFromChangeLabel
