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
      $xobjk = find-Qsql "Select TOP 1 XObjectKey FROM $selectedTableName"
      $result = Get-QObject $selectedTableName "XObjectKey" $xobjk
      Write-Host $result
      $Logger.info($result)
      $columns = $result.Columns
      $allowedColumns = [System.Collections.Generic.List[string]]::new()

      foreach ($selectedColumn in $columns) {

        if(-not $selectedColumn.canEditDisallowedBy.ToString().Contains(' ') ){
          $a = $selectedColumn.ColumnName
          write-host $a + "++++++++++++++++++++++++++"


          $allowedColumns.Add($selectedColumn.columnName)
        }
        else{$a = $selectedColumn.ColumnName
        $b=$selectedColumn.canEditDisallowedBy
          write-host $a + "  "+$b + "---------------------------"}
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
      continue
    }
    $li = $obj.Columns
    #write-host "$li ///////////////////////////////////////////////////"
    # Create case-insensitive hashset of allowed columns
    $allowedSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($col in $AllowedColumnsByTable[$obj.TableName]) {
      $s = $col
      $t = $obj.TableName
      #write-host "$t - $s #####################################################" 
      [void]$allowedSet.Add(($col -as [string]).Trim())
     # write-host "$allowedSet ooooooooooooooooooooooooooooooo"
    }


    # Filter columns
    $filteredCols = New-Object System.Collections.Generic.List[pscustomobject]
    foreach ($col in $obj.Columns) {
      $s = $col.Name
      $t = $obj.TableName
      #write-host "$t - $s #####################################################"
      if ($col.Name -and $allowedSet.Contains($col.Name)) {
        $t = $obj.TableName
        $s = $col.Name
        $filteredCols.Add($col)
        #write-host "$t - $s #####################################################"
      }
    }

    $obj.Columns = $filteredCols
  }

  return $DbObjects
}

# Export module members
Export-ModuleMember -Function @(
  'Get-ColumnPermissionsPsModule',
  'Filter-DbObjectsByAllowedColumnsPsModule'
)
