function Get-ScriptsFromChangeLabel {
  <#
  .SYNOPSIS
    Extracts DialogScript objects from ChangeLabel XML, including UID, ScriptName, and ScriptCode.
  
  .DESCRIPTION
    Parses the TagData.xml file and extracts all DialogScript objects found in ChangeContent,
    returning complete script information without requiring database access.
  
  .PARAMETER Path
    Path to the TagData.xml file.
  
  .OUTPUTS
    Array of PSCustomObjects with UID, ScriptName, and ScriptCode properties.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrWhiteSpace()]
    [string]$Path
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "File not found: $Path"
  }

  # Read and decode file (handles HTML entities)
  $text = Get-Content -LiteralPath $Path -Raw
  for ($i = 0; $i -lt 3; $i++) {
    $text = [System.Net.WebUtility]::HtmlDecode($text)
  }

  # Regex to find DbObject blocks with DialogScript ObjectKey
  $reDbObject = [regex]::new('(?s)<DbObject\b.*?</DbObject>')
  
  # Regex to extract UID from ObjectKey: <T>DialogScript</T><P>UID</P>
  $reObjectKeyUID = [regex]::new(
    '(?s)<Column\b[^>]*\bName\s*=\s*"ObjectKey"[^>]*>.*?<T>DialogScript</T>.*?<P>(?<uid>[^<\s]+)</P>',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
  )

  # Regex to extract values from ChangeContent Diff
  $reScriptName = [regex]::new(
    "(?s)<Op\b[^>]*(?:Columnname|ColumnName)\s*=\s*[""']ScriptName[""'][^>]*>.*?<Value>(?<name>[^<]*)</Value>",
    [System.Text.RegularExpressions.RegexOptions]::Singleline
  )

  $reScriptCode = [regex]::new(
    "(?s)<Op\b[^>]*(?:Columnname|ColumnName)\s*=\s*[""']ScriptCode[""'][^>]*>.*?<Value>(?<code>.*?)</Value>",
    [System.Text.RegularExpressions.RegexOptions]::Singleline
  )

  $scripts = New-Object 'System.Collections.Generic.List[object]'
  $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

  foreach ($dboMatch in $reDbObject.Matches($text)) {
    $dboText = $dboMatch.Value

    # Check if this DbObject is for a DialogScript
    $mKey = $reObjectKeyUID.Match($dboText)
    if (-not $mKey.Success) { continue }

    $uid = $mKey.Groups['uid'].Value.Trim()
    if ([string]::IsNullOrWhiteSpace($uid) -or -not $seen.Add($uid)) { 
      continue 
    }

    # Extract ScriptName and ScriptCode from ChangeContent
    $mName = $reScriptName.Match($dboText)
    $mCode = $reScriptCode.Match($dboText)

    $scriptName = if ($mName.Success) { 
      [System.Net.WebUtility]::HtmlDecode($mName.Groups['name'].Value).Trim() 
    } else { 
      "UnknownScript_$uid" 
    }

    $scriptCode = if ($mCode.Success) { 
      [System.Net.WebUtility]::HtmlDecode($mCode.Groups['code'].Value).Trim() 
    } else { 
      "" 
    }

    # Only add if we have actual code
    if (-not [string]::IsNullOrWhiteSpace($scriptCode)) {
      $scripts.Add([pscustomobject]@{
        UID        = $uid
        ScriptName = $scriptName
        ScriptCode = $scriptCode
      })
    }
  }

  return $scripts
}

# Export module members
Export-ModuleMember -Function @(
  'Get-ScriptsFromChangeLabel'
)