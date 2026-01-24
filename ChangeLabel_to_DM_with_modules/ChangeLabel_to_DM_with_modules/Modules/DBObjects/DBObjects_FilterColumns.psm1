<#
.SYNOPSIS
  DBObjects Module - Handles column permissions retrieval and filters the columns to be deployed based on them.

.DESCRIPTION
  This module provides functions to retrieve
  column-level permissions for database tables.
#>

function Get-ColumnPermissions {
  <#
  .SYNOPSIS
    Retrieves column-level permissions for specified tables.
  
  .PARAMETER BaseUrl
    Base URL of the OIM API.
  
  .PARAMETER Session
    Authenticated web session from Connect-OimApi.
  
  .PARAMETER Tables
    Array of table names to query permissions for.
  
  .OUTPUTS
    Hashtable where keys are table names and values are arrays of allowed column names.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$BaseUrl,
    
    [Parameter(Mandatory)]
    [Microsoft.PowerShell.Commands.WebRequestSession]$Session,
    
    [Parameter(Mandatory)]
    [string[]]$Tables
  )

  $tablesParam = [uri]::EscapeDataString($Tables -join ',')
  $permsUri = "$BaseUrl/SupportPlus/FindColumnsPerms?Tables=$tablesParam"
  
  $headers = @{
    "Accept"            = "application/json"
    "X-Forwarded-For"   = "127.0.0.1"
    "X-Forwarded-Host"  = $BaseUrl -replace '^https?://', ''
    "X-Forwarded-Proto" = if ($BaseUrl -match '^https') { "https" } else { "http" }
  }
  
  try {
    $response = Invoke-WebRequest -Uri $permsUri -Method Get -Headers $headers `
      -WebSession $Session -ErrorAction Stop
    
    $permsObj = $response.Content | ConvertFrom-Json
    
    # Convert to hashtable
    $allowedByTable = @{}
    foreach ($prop in $permsObj.PSObject.Properties) {
      $allowedByTable[$prop.Name] = @($prop.Value)
    }
    
    return $allowedByTable
  }
  catch {
    throw "Failed to retrieve column permissions: $_"
  }
}

function Filter-DbObjectsByAllowedColumns {
  <#
  .SYNOPSIS
    Filters DbObject columns based on permissions from API response.
  
  .PARAMETER DbObjects
    Array of DbObjects to filter.
  
  .PARAMETER AllowedColumnsByTable
    Hashtable of allowed columns per table.
  
  .OUTPUTS
    Filtered array of DbObjects.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][object[]]$DbObjects,
    [Parameter(Mandatory)][hashtable]$AllowedColumnsByTable
  )

  foreach ($obj in $DbObjects) {
    # If table not in permissions, remove all columns
    if (-not $AllowedColumnsByTable.ContainsKey($obj.TableName)) {
      $obj.Columns = New-Object System.Collections.Generic.List[pscustomobject]
      continue
    }

    # Create case-insensitive hashset of allowed columns
    $allowedSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($col in $AllowedColumnsByTable[$obj.TableName]) {
      [void]$allowedSet.Add($col)
    }

    # Filter columns
    $filteredCols = New-Object System.Collections.Generic.List[pscustomobject]
    foreach ($col in $obj.Columns) {
      if ($col.Name -and $allowedSet.Contains($col.Name)) {
        $filteredCols.Add($col)
      }
    }
    $obj.Columns = $filteredCols
  }

  return $DbObjects
}


# Export module members
Export-ModuleMember -Function @(
  'Get-ColumnPermissions',
  'Filter-DbObjectsByAllowedColumns'
)
