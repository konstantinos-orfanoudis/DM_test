
Class DmObjectAttr {

    [string]$name
    [string]$value
    [string]$refAttr
    [DmObject]$objRef
    [bool]$isKey
    [bool]$isRef

    DmObjectAttr([string]$name,[string]$value) { 
        $this.name = $name
        $this.value = $value
    }
    
    DmObjectAttr([string]$name,[string]$value,[bool]$isKey) { 
        $this.name = $name
        $this.value = $value
        $this.isKey = $isKey
    }

    DmObjectAttr([string]$name,[DmObject]$ref,[bool]$isKey) {
        if($ref -eq $null) {
            throw ("null reference for DmObjectAttr.name={0}" -f $name)
        }
        $this.name = $name
        $this.objRef = $ref
        $this.isKey = $isKey
        $this.isRef = $True
    }
}

Class DmObject {

    [string]$tableName
    [string]$pk
    [string]$whereClause
    [DmObjectAttr[]]$attrs
    [bool]$sort

    DmObject([string]$tableName) {
        $this.tableName = $tableName
    }

    DmObject([string]$tableName,[string]$pk) {
        $this.tableName = $tableName
        $this.pk = $pk
    }

    DmObject([string]$tableName,[string]$pk,[string]$whereClause) {
        $this.tableName = $tableName
        $this.pk = $pk
        $this.whereClause = ($whereClause -f $pk)
    }

    [bool]isValidRef() {
        return (![string]::IsNullOrEmpty($this.pk) -or ![string]::IsNullOrEmpty($this.whereClause))
    }

    [bool]isLocalRef() {
        return ($this.isValidRef() -and [string]::IsNullOrEmpty($this.whereClause))
    }

    [DmObjectAttr[]] getKeys() {
        [DmObjectAttr[]]$keys = @()
        foreach($a in $this.attrs) {
            if($a.isKey -and !$keys.Contains($a)) {
                $keys += $a
            }
        }
        return $keys
    }

    [DmObject[]] getRefs() {
        [DmObject[]]$refs = @()
        foreach($a in $this.attrs) {
            if($a.isRef -and $a.objRef.isValidRef() -and !$refs.Contains($a.objRef)) {
                $refs += $a.objRef
            }
        }
        return $refs
    }

    [string]ToString() {
        return ("[DmObject]{0}.{1}" -f $this.tableName,$this.pk)
    }
}

Class DmDoc {

    [hashtable]$keydef = @{}
    [DmObject[]]$objdef = @()

    hidden [xml]$doc = $null
    hidden [System.Xml.XmlElement]$root = $null
	hidden [hashtable]$idmap = @{}
	hidden [int]$iObjRef = 0
	
    DmDoc() {
        $this.doc = New-Object System.Xml.XmlDocument
        $this.doc.AppendChild($this.doc.CreateXmlDeclaration("1.0","utf-8",$null))
        $this.root = $this.doc.CreateNode("element","Objects",$null)
        $this.doc.AppendChild($this.root)

        $keys = $this.doc.CreateNode("element","Keys",$null)
        $this.root.AppendChild($keys)
    }

    AddObjDef([DmObject]$obj) {
        $this.objdef += $obj

		if(!$this.idmap.ContainsKey([string]$obj.pk)) {
			$this.idmap.Add([string]$obj.pk,$this._nextObjRef())
		}

        foreach($a in $obj.getKeys()) {
            $keys = $this.keydef[$obj.tableName]
            if($keys -eq $null) {
                $keys = @()
            }
            if(!$keys.Contains($a.name)) {
                $keys += $a.name
                $this.keydef[$obj.tableName] = $keys
            }
        }
    }

	[string] _nextObjRef() {
		return ("object{0:000}" -f ($this.iObjRef++))
	}
	
    _sortObjects() {
		[int]$iterationLimit = 1000
        do {
            $moved = $False

            for($i=0; $i -lt $this.objdef.Length; $i++) {
                $o = $this.objdef[$i]
                if(!$o.sort) {
                    continue
                }

                foreach($ref in $o.getRefs()) {
                    # Don't need to sort 'where' clause refs
                    if(!$ref.isLocalRef()) {
                        continue
                    }                    
                    $idref = [string]$ref.pk
                    #Write-Host ("{0} at position {1} has ref to {2}" -f $o,$i,$idref)
                    for($j=0; $j -lt $this.objdef.Length; $j++) {
                        $o2 = $this.objdef[$j]
                        if(!$o2.sort) {
                            continue
                        }
                        if($o2.pk -eq $idref -and $j -gt $i) {
                            #Write-Host ("  {0} found at position {1}, moving to {2}" -f $o2,$j,$i)
                            $tmp = $this.objdef[$i]
                            $this.objdef[$i] = $this.objdef[$j]
                            $this.objdef[$j] = $tmp
                            $moved = $True
                        }
                    }                    
                }
            }
			
			if(--$iterationLimit -eq 0) {
				throw ("iteration limit of {0} reached while sorting!" -f $iterationLimit)
			}			
        } while($moved)
    }

    _writeKeys() {
        $keys = $this.root.SelectSingleNode("//Keys")

        foreach($k in $this.keydef.Keys) {
            $elem = $this.doc.CreateNode("element",$k,$null)
			$keys.AppendChild($elem)
			$elem.InnerText = [string]::Join(",",$this.keydef[$k])
        }

    }
    _writeObjects() {
        foreach($obj in $this.objdef) {
            $objelem = $this.doc.CreateNode("element",$obj.tableName,$null)
            $this.root.AppendChild($objelem)

            $id = $this.doc.CreateAttribute("id")
            $id.Value = $this.idmap[$obj.pk]
            $objelem.Attributes.Append($id)

            foreach($attr in $obj.attrs) {
                $attrelem = $this.doc.CreateNode("element",$attr.name,$null)
                $objelem.AppendChild($attrelem)

                if(!$attr.isRef -and ![string]::IsNullOrWhiteSpace($attr.value)) {
                    # Simple scalar (non-reference) attributes
                    if($attr.value -match "`r|`n") {
                        $cdata = $this.doc.CreateCDataSection($attr.value)
                        $attrelem.AppendChild($cdata)
                    } else {
                        $attrelem.InnerText = $attr.value
                    }
                
                } else {
                    # Handle object references
                    if($attr.objRef -ne $null -and $attr.objRef.isValidRef()) {
                        $objRefelem = $this.doc.CreateNode("element",$attr.objRef.tableName,$null)
                        $attrelem.AppendChild($objRefelem)

                        # whereClause takes precedence over local idref
                        #if(![string]::IsNullOrEmpty($attr.objRef.whereClause)) {
                        if(!$attr.objRef.isLocalRef()) {
                            $whereClause = $this.doc.CreateAttribute("where")
                            $objRefelem.Attributes.Append($whereClause)
                            $whereClause.Value = $attr.objref.whereClause
                        }
                        else { #if(![string]::IsNullOrEmpty($attr.objRef.pk)) {
                            $idref = $this.doc.CreateAttribute("idref")
                            $objRefelem.Attributes.Append($idref)
                            $idref.Value = $this.idmap[$attr.objRef.pk]
                        }

                        # Add column attribute if defined
                        if($attr.refAttr -ne $null) {
                            $refcolumn = $this.doc.CreateAttribute("column")
                            $objRefelem.Attributes.Append($refcolumn) 
                            $refcolumn.Value = $attr.refcolumn
                        }
                    } else {
                        # Remove element if reference is empty or invalid
                        $objelem.RemoveChild($attrelem)
                    }
                }
            }
        }
    }

    ToXml([string]$filepath) {
        $this._sortObjects()

        $this._writeKeys()
        $this._writeObjects()

        $this.doc.Save($filepath)
    }
}


Function New-DmObject() {
    param([Parameter(Mandatory=$True)][VI.DB.IColElem]$elem) 

    [VI.DB.Entities.IEntity]$entity = $elem.GetEntity()
    Return [DmObject]::new($entity.Tablename,$entity.LogId)
}

Function New-DmObjectAttr() {
    param([Parameter(Mandatory=$True)][VI.DB.IColElem]$elem, [Parameter(Mandatory=$True)][string]$column, [bool]$isKey)

    [VI.DB.Entities.IEntity]$entity = $elem.GetEntity()
    if($entity.Columns.Contains($column)) {
        [object]$raw = $elem.GetRaw($column)
        [string]$val = $null
        switch($raw.GetType().Name) {
            "Boolean"  { $val = if([bool]$raw) { "1" } else { "0" } }
            "DateTime" { $val = ("{0:yyyy/MM/dd HH:mm:ss}" -f [datetime]$raw) }
            default    { $val = $raw.ToString() }
        }
        $attr = [DmObjectAttr]::new($column,$val,$isKey)
        return $attr
    } else {
        throw ("column {0} not found in entity of type {1}" -f $column,$entity.Tablename)
    }
}

Function New-DmObjectAttrRef() {
    param([Parameter(Mandatory=$True)][VI.DB.IColElem]$elem, [Parameter(Mandatory=$True)][string]$column, [Parameter(Mandatory=$True)][string]$fkType, [bool]$isKey, [bool]$refBywhereClause)

    [VI.DB.Entities.IEntity]$entity = $elem.GetEntity()
    if($entity.Columns.Contains($column)) {
        [string]$pk = $elem.GetValue($column).String
        [string]$whereClause = $null
        if($refBywhereClause) {
            $whereClause = ("{0} = '{1}'" -f $column,$pk)
        }
        $objRef = [DmObject]::new($fkType,$pk,$whereClause)
        $attr = [DmObjectAttr]::new($column,$objRef,$isKey)
        return $attr
    } else {
        throw ("column {0} not found in entity of type {1}" -f $column,$entity.Tablename)
    }
}

Export-ModuleMember -Function New-DmObject
Export-ModuleMember -Function New-DmObjectAttr
Export-ModuleMember -Function New-DmObjectAttrRef
