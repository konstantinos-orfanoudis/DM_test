<#
.SYNOPSIS
  DBObjects Module - Handles column permissions retrieval and filters the columns to be deployed based on them.

.DESCRIPTION
  This module provides functions to retrieve
  column-level permissions for database tables.
#>

function Get-ColumnPermissionsPsModule {
  <#
  .SYNOPSIS
    Retrieves column-level permissions for specified tables.
  
  .PARAMETER Session
    Authenticated session from Connect-OimPSModule.
  
  .PARAMETER Tables
    Array of table names to query permissions for.
  
  .OUTPUTS
    Hashtable where keys are table names and values are arrays of allowed column names.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [Object]$Session,
    
    [Parameter(Mandatory)]
    [string[]]$Tables
  )

  try {
    $connection = $session.Connection

    # Convert to hashtable
    $allowedByTable = @{}
    $Logger = Get-logger
    $Logger.info("The selected teable(s):")
    foreach ($selectedTableName in $Tables) {
      Write-Host  $selectedTableName
      $selectedTables = $connection.Tables  | Where-Object { $_.TableName -eq $selectedTableName }
      Write-Host $selectedTables
      $Logger.info($selectedTables)
      $columns = $selectedTables.Columns
      $allowedColumns = [System.Collections.Generic.List[string]]::new()

      foreach ($selectedColumn in $columns) {
        if($selectedColumn.canInsert.AnyBitSet){
          $allowedColumns.Add($selectedColumn.columnName)
        }
        
      }

      
      $allowedByTable[$selectedTableName] = $allowedColumns;
    }
    
    return $allowedByTable
  }
  catch {
    $Logger = Get-Logger
    $Logger.info("Failed to retrieve column permissions: $_")
    throw "Failed to retrieve column permissions: $_"
  }
}

function Filter-DbObjectsByAllowedColumnsPsModule {
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
      write-host " $AllowedColumnsByTable xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

      continue
    }

    # Create case-insensitive hashset of allowed columns
    $allowedSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($col in $AllowedColumnsByTable[$obj.TableName]) {
      [void]$allowedSet.Add($col)
    }
    write-host " $allowedSet kkkkkkkkkkkkkkkkkkkkkkkkkkk"

    # Filter columns
    $filteredCols = New-Object System.Collections.Generic.List[pscustomobject]
    foreach ($col in $obj.Columns) {
      if ($col.Name -and $allowedSet.Contains($col.Name)) {
        $filteredCols.Add($col)
      }
    }
    write-host " $filteredCols @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
    $obj.Columns = $filteredCols
  }

  return $DbObjects
}

# Export module members
Export-ModuleMember -Function @(
  'Get-ColumnPermissionsPsModule',
  'Filter-DbObjectsByAllowedColumnsPsModule'
)
