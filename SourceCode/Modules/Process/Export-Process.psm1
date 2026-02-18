Using module ..\..\DmDoc.psm1

<#
.SYNOPSIS
Exports a job chain from the OIM database to Intragen DeploymentManager xml.

.DESCRIPTION
Exports a job chain from the OIM database to Intragen DeploymentManager xml.

.PARAMETER Name
Specifies the job chain name.

.PARAMETER TableName
Specifies the base table name.

.PARAMETER OutFilePath
Specifies the file to write to.

.INPUTS
As per parameters.

.OUTPUTS
DeploymentManager xml file.

.EXAMPLE
Export-Process -Name "My Job Chain" -TableName "Person" -OutFilePath "C:\temp\myjobchain.xml"
#>
function Export-Process{
param(
    [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)][string]$Name ,
    [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)][string]$TableName ,
    [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)][string]$OutFilePath
)

$dm = [DmDoc]::new()

$oimJobChain = Find-QObject JobChain ("Name=N'{0}' and UID_DialogTable=(select UID_DialogTable from DialogTable where TableName=N'{1}')" -f $Name,$TableName)
if(!$oimJobChain) {
    $Logger = Get-Logger
    $Logger.info("Name=N'{0}' and UID_DialogTable=(select UID_DialogTable from DialogTable where TableName=N'{1}')" -f $Name,$TableName)
    throw ("JobChain {0}.{1} not found" -f $TableName,$Name)
}
if($oimJobChain.Length -gt 1) {
    $Logger = Get-Logger
    $Logger.info("JobChain {0}.{1} not unique!" -f $TableName,$Name)
    throw ("JobChain {0}.{1} not unique!" -f $TableName,$Name)
}

# Create the JobChain
$UID_JobChain = $oimJobChain.GetValue("UID_JobChain").String
$oimJobChain | ForEach-Object {

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

# Create the Jobs
$oimJobs = Find-QObject Job ("UID_JobChain = '{0}'" -f $UID_JobChain)
$oimJobs | ForEach-Object {

    $j = New-DmObject $_
	$j.attrs += New-DmObjectAttr $_ "UID_Job" $True
	$j.attrs += New-DmObjectAttr $_ "Name"
	$j.attrs += New-DmObjectAttr $_ "Description"
    $j.attrs += New-DmObjectAttrRef $_ "UID_JobChain" "JobChain" $True
    $j.attrs += New-DmObjectAttrRef $_ "UID_JobTask" "JobTask" $False $True
    $j.attrs += New-DmObjectAttrRef $_ "UID_SuccessJob" "Job"
    $j.attrs += New-DmObjectAttrRef $_ "UID_ErrorJob" "Job"
    $j.attrs += New-DmObjectAttr $_ "IsSplitOnly"
    $j.attrs += New-DmObjectAttr $_ "IsNoDBQueueDefer"
    $j.attrs += New-DmObjectAttr $_ "GenCondition"
    $j.attrs += New-DmObjectAttr $_ "PreCode"
	$j.attrs += New-DmObjectAttr $_ "IsToFreezeOnError"
	$j.attrs += New-DmObjectAttr $_ "IgnoreErrors"
	$j.attrs += New-DmObjectAttr $_ "DeferOnError"
    if($_.GetValue("DeferOnError").Bool) {
        $j.attrs += New-DmObjectAttr $_ "MinutesToDefer"
        $j.attrs += New-DmObjectAttr $_ "Retries"
    }
    $j.attrs += New-DmObjectAttr $_ "ServerDetectScript"
    if([string]::IsNullOrWhiteSpace($_.GetValue("ServerDetectScript").String)) {
        $j.attrs += New-DmObjectAttrRef $_ "UID_QBMServerTag" "QBMServerTag" $False $True
    }
    $j.attrs += New-DmObjectAttr $_ "NotifyAddress"
    $j.attrs += New-DmObjectAttr $_ "NotifyAddressSuccess"
    $j.attrs += New-DmObjectAttr $_ "NotifyBody"
    $j.attrs += New-DmObjectAttr $_ "NotifyBodySuccess"
    $j.attrs += New-DmObjectAttr $_ "NotifySender"
    $j.attrs += New-DmObjectAttr $_ "NotifySenderSuccess"
    $j.attrs += New-DmObjectAttr $_ "NotifySubject"
    $j.attrs += New-DmObjectAttr $_ "NotifySubjectSuccess"
    $j.sort = $True

    $dm.AddObjDef($j)

    # Create the JobRunParameters
    $oimJobRunParameters = Find-QObject JobRunParameter ("UID_Job = '{0}'" -f $_.GetValue("UID_Job").String)
    $oimJobRunParameters | ForEach-Object {
        $e = $_.Create()
        $jrp = New-DmObject $_
        $jrp.attrs += New-DmObjectAttrRef $_ "UID_Job" "Job" $True
        $jrp.attrs += New-DmObjectAttrRef $_ "UID_JobParameter" "JobParameter" $True $True
        $jrp.attrs += New-DmObjectAttr $_ "Name"
        $jrp.attrs += New-DmObjectAttr $_ "ValueTemplate"
        if(($e.Columns | Where-Object { $_.Columnname -eq "IsCompressed"}).CanEdit) {
            $jrp.attrs += New-DmObjectAttr $_ "IsCompressed"
        }
        if(($e.Columns | Where-Object { $_.Columnname -eq "IsCrypted"}).CanEdit) {
            $jrp.attrs += New-DmObjectAttr $_ "IsCrypted"
        }
        if(($e.Columns | Where-Object { $_.Columnname -eq "IsPartialCrypted"}).CanEdit) {
            $jrp.attrs += New-DmObjectAttr $_ "IsPartialCrypted"
        }
        if(($e.Columns | Where-Object { $_.Columnname -eq "IsHidden"}).CanEdit) {
            $jrp.attrs += New-DmObjectAttr $_ "IsHidden"
        }
        $jrp.sort = $True
        $e.Discard()

        $dm.AddObjDef($jrp)
    }
}



# Create the Event
$oimQBMEvent = Find-QObject QBMEvent ("exists(select 1 from JobEventGen jeg join JobChain jc on jc.UID_JobChain=jeg.UID_JobChain	where jc.UID_JobChain = '{0}' and QBMEvent.UID_QBMEvent=jeg.UID_QBMEvent)" -f $UID_JobChain)
$oimQBMEvent | ForEach-Object {
    $e = New-DmObject $_
	$e.attrs += New-DmObjectAttr $_ "UID_QBMEvent" $True
    $e.attrs += New-DmObjectAttrRef $_ "UID_DialogTable" "DialogTable" $False $True
    $e.attrs += New-DmObjectAttr $_ "EventName"
    $e.attrs += New-DmObjectAttr $_ "DisplayName"

    $dm.AddObjDef($e)
}

# Create the JobEventGen
$oimJobEventGen = Find-QObject JobEventGen ("UID_JobChain = '{0}'" -f $UID_JobChain)
$oimJobEventGen | ForEach-Object {

    $jeg = New-DmObject $_
	$jeg.attrs += New-DmObjectAttr $_ "UID_JobEventGen" $True
    $jeg.attrs += New-DmObjectAttrRef $_ "UID_QBMEvent" "QBMEvent" $True
    $jeg.attrs += New-DmObjectAttrRef $_ "UID_JobChain" "JobChain"
    $jeg.attrs += New-DmObjectAttr $_ "OrderNr"
    $jeg.attrs += New-DmObjectAttr $_ "ProcessDisplay"

    $dm.AddObjDef($jeg)
}

# Wire the JobChain to the first Job
$oimJobChain | ForEach-Object {

    $jc = New-DmObject $_
	$jc.attrs += New-DmObjectAttrRef $_ "UID_JobChain" "JobChain" $True
    $jc.attrs += New-DmObjectAttrRef $_ "UID_Job" "Job"

    $dm.AddObjDef($jc)
}


$dm.ToXml($OutFilePath)
}

# Export module members
Export-ModuleMember -Function @(
  'Export-Process'
)
