Using module ..\..\DmDoc.psm1

function Export-Process{
param(
    [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)][string]$Name , 
    [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)][string]$TableName , 
    [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)][string]$OutFilePath
)

$dm = [DmDoc]::new()

$oimJobChain = Find-QObject JobChain ("Name=N'{0}' and UID_DialogTable=(select UID_DialogTable from DialogTable where TableName=N'{1}')" -f $Name,$TableName)
if(!$oimJobChain) {
    throw ("JobChain {0}.{1} not found" -f $TableName,$Name)
}
if($oimJobChain.Length -gt 1) {
    throw ("JobChain {0}.{1} not unique!" -f $TableName,$Name)
}

$UID_JobChain = $oimJobChain.GetValue("UID_JobChain").String
$oimJobChain |% {
    $jc = New-DmObject $_
    $jc.attrs += New-DmObjectAttr $_ "UID_JobChain" $True
    $jc.attrs += New-DmObjectAttr $_ "Name" 
    $jc.attrs += New-DmObjectAttrRef $_ "UID_DialogTable" "DialogTable" $False $True
    $jc.attrs += New-DmObjectAttr $_ "CustomRemarks"
    $jc.attrs += New-DmObjectAttr $_ "Description"
    $jc.attrs += New-DmObjectAttr $_ "GenCondition"
    $jc.attrs += New-DmObjectAttr $_ "LimitationCount"
    $jc.attrs += New-DmObjectAttr $_ "LimitationWarning"
    $jc.attrs += New-DmObjectAttr $_ "NoGenerate"
    $jc.attrs += New-DmObjectAttr $_ "PreCode"
    $jc.attrs += New-DmObjectAttr $_ "ProcessDisplay"
    $jc.attrs += New-DmObjectAttr $_ "ProcessTracking"
    $jc.attrs += New-DmObjectAttr $_ "LayoutPositions"
    $dm.AddObjDef($jc)
}

$dm.ToXml($OutFilePath)
}

Export-ModuleMember -Function @('Export-Process')
