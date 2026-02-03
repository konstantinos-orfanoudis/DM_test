Set-StrictMode -Version Latest

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

  $results = New-Object 'System.Collections.Generic.List[object]'
  if (-not $taggedChangeDbos) { return $results }

  # Extract UID_JobChain from Diff text (ChangeContent)
  $reUidJobChain = [regex]::new(
    "(?s)<Op\b[^>]*(?:Columnname|ColumnName)\s*=\s*[""']UID_JobChain[""'][^>]*>.*?<Value>\s*(?<uid>[^<\s]+)\s*</Value>",
    [System.Text.RegularExpressions.RegexOptions]::Singleline
  )

  foreach ($dbo in $taggedChangeDbos) {

    # QBMTaggedChange Key attribute
    $qbmTable = $dbo.SelectSingleNode("./*[local-name()='Key']/*[local-name()='Table' and @Name='QBMTaggedChange']")
    $taggedChangeKey = if ($qbmTable) { $qbmTable.GetAttribute("Key") } else { $null }
    if ([string]::IsNullOrWhiteSpace($taggedChangeKey)) { continue }

    # 1) Try: JobChain UID from ObjectKey column (when the object itself is a JobChain)
    $tNode = $dbo.SelectSingleNode(".//*[local-name()='Column' and @Name='ObjectKey']//*[local-name()='T']")
    $pNode = $dbo.SelectSingleNode(".//*[local-name()='Column' and @Name='ObjectKey']//*[local-name()='P']")

    if ($tNode -and $pNode) {
      $objType = $tNode.InnerText.Trim()
      $objUid  = $pNode.InnerText.Trim()

      if ($objType -match '(?i)JobChain' -and -not [string]::IsNullOrWhiteSpace($objUid)) {
        $s = Open-QSql
        $wc = "select Name, UID_DialogTable from JobChain where UID_JobChain = '$objUid'"
        $pr = Find-QSql $wc -dict 
        $uid_table = $pr["UID_DialogTable"]
        $processName = $pr["Name"]
        $wc = "select TableName from DialogTable where UID_DialogTable = '$uid_table'"
        $t = Find-QSql $wc -dict 
        $TableName = $t["TableName"]
        Close-QSql
        
        [void]$results.Add([pscustomobject]@{
          TableName = $TableName
          Name      = $processName
        })
      }
    }

    # 2) Try: UID_JobChain from ChangeContent Diff (e.g., JobEventGen rows)
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
        # Decode entities a few times (safe even if already decoded)
        $decoded = $raw
        for ($i=0; $i -lt 3; $i++) { $decoded = [System.Net.WebUtility]::HtmlDecode($decoded) }

        $m = $reUidJobChain.Match($decoded)
        if ($m.Success) {
          $uid = $m.Groups["uid"].Value.Trim()
           
          $s = Open-QSql
          $wc = "select Name, UID_DialogTable from JobChain where UID_JobChain = '$uid'"
          $pr = Find-QSql $wc -dict 
          $uid_table = $pr["UID_DialogTable"]
          $processName = $pr["Name"]
          $wc = "select TableName from DialogTable where UID_DialogTable = '$uid_table'"
          $t = Find-QSql $wc -dict 
          $TableName = $t["TableName"]
          Close-QSql
          
          [void]$results.Add([pscustomobject]@{
            TableName = $TableName
            Name      = $processName
          })
        }
      }
    }
  }

  return $results
}

Export-ModuleMember -Function GetAllProcessFromChangeLabel
