
Import-Module "C:\Users\aiuser\Desktop\DeploymentManager-4.0.6-beta\Intragen.Deployment.OneIdentity.dll"
Import-Module  "C:\Users\aiuser\Desktop\DeploymentManager-4.0.6-beta\Intragen.Quest.Command.PowerShell.dll" 
Invoke-QDeploy -Console -DeploymentPath C:\DMWorkshop2\Config\Example

$session = Get-QSession -default 
Write-Host $session