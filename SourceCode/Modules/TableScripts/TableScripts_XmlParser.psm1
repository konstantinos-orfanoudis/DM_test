function Get-DialogTableScriptsFromChangeLabel {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrWhiteSpace()]
    [string]$ZipPath,

    # the <T> value to match inside ObjectKey
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrWhiteSpace()]
    [string]$TypeName = "DialogTable"
  )

  if (-not (Test-Path -LiteralPath $ZipPath)) {
    throw "File not found: $ZipPath"
  }

  $text = Get-Content -LiteralPath $ZipPath -Raw

  # Decode entities a few times (safe even if already decoded)
  for ($i = 0; $i -lt 3; $i++) {
    $text = [System.Net.WebUtility]::HtmlDecode($text)
  }


  # 1) Iterate DbObject blocks
  $dbObjectPattern = '(?is)<DbObject\b[^>]*>.*?</DbObject>'
  




  # 2) Extract UID_DialogTable from ObjectKey:
  #    <Column Name="ObjectKey"> ... <Key><T>DialogTable</T><P>...</P></Key>
  $objectKeyPattern = '(?is)<Column\b[^>]*\bName\s*=\s*"(?:ObjectKey)"[^>]*>.*?' +
                      '<Key>\s*<T>\s*' + [regex]::Escape($TypeName) + '\s*</T>\s*<P>\s*(?<p>[^<\s]+)\s*</P>\s*</Key>'

  # 3) Check ChangeContent for each script column Op Columnname="..."
  $changeContentBase = '(?is)<Column\b[^>]*\bName\s*=\s*"(?:ChangeContent)"[^>]*>.*?'
  
  #$changeContentBase = '(?is)<Column\b(?:(?!</Column>).)*?\bName\s*=\s*"ChangeContent"\b(?:(?!</Column>).)*?>\s*(?:<Value>)?(?<cc>.*?)(?:</Value>)?\s*</Column>'


  function Test-HasOpColumn {
    param(
      [Parameter(Mandatory)][string]$DbObjectBlock,
      [Parameter(Mandatory)][string]$ColumnName
    )
    #$pat = $changeContentBase + '<Op\b[^>]*\bColumn(?:name|Name)\s*=\s*"' + [regex]::Escape($ColumnName) + '"\b'
    $pat = $changeContentBase + '<Op\b[^>]*\bColumn(?:name|Name)\s*=\s*"' + [regex]::Escape($ColumnName) + '"'

    return [regex]::IsMatch($DbObjectBlock, $pat)
  }

  # Deduplicate by UID_DialogTable
  $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  $rows = New-Object 'System.Collections.Generic.List[object]'

  foreach ($dbo in [regex]::Matches($text, $dbObjectPattern)) {
    $block = $dbo.Value



    # Extract DialogTable key (P value) => UID_DialogTable
    $mKey = [regex]::Match($block, $objectKeyPattern)
    if (-not $mKey.Success) { continue }

    $uidDialogTable = $mKey.Groups['p'].Value.Trim()
    if (-not $uidDialogTable) { continue }
    # Detect which script columns appear in ChangeContent
    $onSaving     = Test-HasOpColumn -DbObjectBlock $block -ColumnName 'OnSavingScript'
    $onSaved      = Test-HasOpColumn -DbObjectBlock $block -ColumnName 'OnSavedScript'
    $onLoaded     = Test-HasOpColumn -DbObjectBlock $block -ColumnName 'OnLoadedScript'
    $onDiscarded  = Test-HasOpColumn -DbObjectBlock $block -ColumnName 'OnDiscardedScript'
    $onDiscarding = Test-HasOpColumn -DbObjectBlock $block -ColumnName 'OnDiscardingScript'

    # Keep ONLY if at least one of the script columns is present
    if (-not ($onSaving -or $onSaved -or $onLoaded -or $onDiscarded -or $onDiscarding)){
      continue
    }

    # One object per UID_DialogTable (if multiple DbObjects exist for same table, we OR the flags)
    if (-not $seen.Add($uidDialogTable)) {
      $existing = $rows | Where-Object { $_.UID_DialogTable -eq $uidDialogTable } | Select-Object -First 1
      if ($null -ne $existing) {
        $existing.OnSavingScript     = $existing.OnSavingScript     -or $onSaving
        $existing.OnSavedScript      = $existing.OnSavedScript      -or $onSaved
        $existing.OnLoadedScript     = $existing.OnLoadedScript     -or $onLoaded
        $existing.OnDiscardedScript  = $existing.OnDiscardedScript  -or $onDiscarded
        $existing.OnDiscardingScript = $existing.OnDiscardingScript -or $onDiscarding
      }
      continue
    }

    $rows.Add([pscustomobject]@{
      UID_DialogTable     = $uidDialogTable     
      OnSavingScript      = [bool]$onSaving
      OnSavedScript       = [bool]$onSaved
      OnLoadedScript      = [bool]$onLoaded
      OnDiscardedScript   = [bool]$onDiscarded
      OnDiscardingScript  = [bool]$onDiscarding
    }
    ) | Out-Null
  }
  return $rows
  
}

# Export module members
Export-ModuleMember -Function @(
  'Get-DialogTableScriptsFromChangeLabel'
)
