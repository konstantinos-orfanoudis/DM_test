Import-Module "$PSScriptRoot\..\Common\XDateCheck.psm1" -Force

function Get-TemplatesFromChangeContent {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrWhiteSpace()]
    [string]$ZipPath
  )

  if (-not (Test-Path -LiteralPath $ZipPath)) { 
    $Logger = Get-Logger
    $Logger.Info("File not found: $ZipPath" )
    throw "File not found: $ZipPath" 
  }

  # Extract change label creation date (loads XML separately from the regex text below)
  $labelDate = Get-ChangeLabelCreationDate -ZipPath $ZipPath

  # Read whole file + decode a few times (handles &lt; and &amp;lt;)
  $text = Get-Content -LiteralPath $ZipPath -Raw
  $text = [System.Net.WebUtility]::HtmlDecode($text) # If more than 1 time encoded, use the For-Block "for ($i = 0; $i -lt 3; $i++) { $text = [System.Net.WebUtility]::HtmlDecode($text) }"

  function Sanitize-FilePart([string]$s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return "" }
    $invalid = [System.IO.Path]::GetInvalidFileNameChars()
    foreach ($ch in $invalid) { $s = $s.Replace($ch, '_') }
    return $s.Trim()
  }

  $reDbObject = [regex]::new('(?s)<DbObject\b.*?</DbObject>')

  # ObjectKey: <Column Name="ObjectKey"> ... <T>DialogColumn</T><P>EPC-...</P> ...
  $reObjectKeyTP = [regex]::new(
    '(?s)<Column\b[^>]*\bName\s*=\s*"ObjectKey"[^>]*>.*?<Value>.*?<T>(.*?)</T>.*?<P>(.*?)</P>.*?</Value>.*?</Column>'
  )

  $reDiff = [regex]::new('(?s)<Diff\b.*?</Diff>')

  # Template value inside Diff (tolerant, does NOT require </Op>)
  $reTemplateValue = [regex]::new(
    "(?s)<Op\b[^>]*(?:Columnname|ColumnName)\s*=\s*[""']Template[""'][^>]*>.*?<Value>(.*?)</Value>"
  )

  $reOverwriteTrue = [regex]::new(
    "(?s)<Op\b[^>]*(?:Columnname|ColumnName)\s*=\s*[""']IsOverwritingTemplate[""'][^>]*>.*?<Value>\s*True\s*</Value>"
  )

  # First pass: Build map of ObjectKey -> IsOverwritingTemplate flag
  Write-Host "  [DEBUG] Building IsOverwritingTemplate map..." -ForegroundColor Gray
  $overwriteMap = @{}
  
  foreach ($dboMatch in $reDbObject.Matches($text)) {
    $dboText = $dboMatch.Value
    
    # Extract ObjectKey
    $mKey = $reObjectKeyTP.Match($dboText)
    if (-not $mKey.Success) { continue }
    
    $tableName  = $mKey.Groups[1].Value
    $columnName = $mKey.Groups[2].Value
    $objectKey = "$tableName|$columnName"
    
    # Check all Diffs in this DbObject for IsOverwritingTemplate
    foreach ($diffMatch in $reDiff.Matches($dboText)) {
      $diff = $diffMatch.Value
      if ($reOverwriteTrue.IsMatch($diff)) {
        $overwriteMap[$objectKey] = $true
        Write-Host "    Found IsOverwritingTemplate=True for: $tableName -> $columnName" -ForegroundColor Cyan
        $Logger = Get-Logger
        $Logger.Info("  Found IsOverwritingTemplate=True for: $tableName -> $columnName" )
        break
      }
    }
  }

  # Second pass: Extract templates and apply overwrite flag
  Write-Host "  [DEBUG] Extracting templates..." -ForegroundColor Gray
  $templates = New-Object System.Collections.Generic.List[object]

  foreach ($dboMatch in $reDbObject.Matches($text)) {
    $dboText = $dboMatch.Value

    # Default context
    $tableName  = "UnknownTable"
    $columnName = "UnknownColumn"

    $mKey = $reObjectKeyTP.Match($dboText)
    # Capture raw UID_DialogColumn before sanitization (needed for DB freshness check)
    $uidDialogColumn = if ($mKey.Success) { $mKey.Groups[2].Value } else { $null }
    if ($mKey.Success) {
      $tableName  = $mKey.Groups[1].Value
      $columnName = $mKey.Groups[2].Value
    }

    $tableName  = Sanitize-FilePart $tableName
    $columnName = Sanitize-FilePart $columnName
    if ([string]::IsNullOrWhiteSpace($tableName))  { $tableName  = "UnknownTable" }
    if ([string]::IsNullOrWhiteSpace($columnName)) { $columnName = "UnknownColumn" }

    # --- XDateUpdated freshness check (pass 2) ---
    if ($null -ne $labelDate -and -not [string]::IsNullOrWhiteSpace($uidDialogColumn)) {
      $allow = Confirm-ExportIfStale -TableName 'DialogColumn' `
                 -WhereClause "UID_DialogColumn = '$uidDialogColumn'" `
                 -LabelDate $labelDate `
                 -ObjectDescription "DialogColumn '$tableName.$columnName' (UID = $uidDialogColumn)"
      if (-not $allow) { continue }
    }

    $objectKey = "$tableName|$columnName"
    $isOverwrite = if ($overwriteMap.ContainsKey($objectKey)) { $overwriteMap[$objectKey] } else { $false }

    foreach ($diffMatch in $reDiff.Matches($dboText)) {
      $diff = $diffMatch.Value

      # Only proceed if this Diff contains a Template Op
      $tm = $reTemplateValue.Matches($diff)
      if ($tm.Count -eq 0) { continue }

      foreach ($m in $tm) {
        # VB file content = inner Template Op <Value>...</Value>
        $vbContent = [System.Net.WebUtility]::HtmlDecode($m.Groups[1].Value).Trim()

        Write-Host "Found template for: $tableName -> $columnName (Overwrite: $isOverwrite)" -ForegroundColor Gray
     
       # $Logger.info("Found template for: $tableName -> $columnName (Overwrite: $isOverwrite)")
        
        $templates.Add([pscustomobject]@{
          TableName             = $tableName
          ColumnName            = $columnName
          IsOverwritingTemplate = $isOverwrite
          Content               = $vbContent
          FetchContentFromDb    = $false
        })
      }
    }
  }
  # Third pass: Separate handling for overwrite-only changes
  # These are DbObjects where the Diff only toggles IsOverwritingTemplate without any Template content.
  # The actual template VB code exists in the database and must be fetched by the exporter.
  Write-Host "  [DEBUG] Checking for overwrite-only changes (no Template content in Diff)..." -ForegroundColor Gray

  $reOverwriteValue = [regex]::new(
    "(?s)<Op\b[^>]*(?:Columnname|ColumnName)\s*=\s*[""']IsOverwritingTemplate[""'][^>]*>.*?<Value>\s*(True|False)\s*</Value>"
  )

  foreach ($dboMatch in $reDbObject.Matches($text)) {
    $dboText = $dboMatch.Value

    $mKey = $reObjectKeyTP.Match($dboText)
    if (-not $mKey.Success) { continue }

    # Capture raw UID_DialogColumn before sanitization
    $uidDialogColumn = $mKey.Groups[2].Value
    $tableName  = Sanitize-FilePart $mKey.Groups[1].Value
    $columnName = Sanitize-FilePart $mKey.Groups[2].Value
    if ([string]::IsNullOrWhiteSpace($tableName))  { $tableName  = "UnknownTable" }
    if ([string]::IsNullOrWhiteSpace($columnName)) { $columnName = "UnknownColumn" }

    # --- XDateUpdated freshness check (pass 3) ---
    if ($null -ne $labelDate -and -not [string]::IsNullOrWhiteSpace($uidDialogColumn)) {
      $allow = Confirm-ExportIfStale -TableName 'DialogColumn' `
                 -WhereClause "UID_DialogColumn = '$uidDialogColumn'" `
                 -LabelDate $labelDate `
                 -ObjectDescription "DialogColumn '$tableName.$columnName' (UID = $uidDialogColumn)"
      if (-not $allow) { continue }
    }

    foreach ($diffMatch in $reDiff.Matches($dboText)) {
      $diff = $diffMatch.Value

      # Skip if this Diff already has Template content (handled by second pass)
      if ($reTemplateValue.IsMatch($diff)) { continue }

      # Check if this Diff has an IsOverwritingTemplate Op
      $mOverwrite = $reOverwriteValue.Match($diff)
      if (-not $mOverwrite.Success) { continue }

      $overwriteFlag = ($mOverwrite.Groups[1].Value.Trim() -eq 'True')

      Write-Host "Found overwrite-only change for: $tableName -> $columnName (Overwrite: $overwriteFlag) [Content to be fetched from DB]" -ForegroundColor Yellow
      $Logger = Get-Logger
      $Logger.Info("Found overwrite-only change for: $tableName -> $columnName (Overwrite: $overwriteFlag) [Content to be fetched from DB]")

      $templates.Add([pscustomobject]@{
        TableName             = $tableName
        ColumnName            = $columnName
        IsOverwritingTemplate = $overwriteFlag
        Content               = $null
        FetchContentFromDb    = $true
      })
    }
  }

  $templates = $templates | Sort-Object TableName, ColumnName, IsOverwritingTemplate, Content -Unique
  return $templates
}

# Export module members
Export-ModuleMember -Function @(
  'Get-TemplatesFromChangeContent'
)