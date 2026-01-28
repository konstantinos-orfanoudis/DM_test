# call MainPsModule DM Test folder
./MainPsModule.ps1 -Path C:\Users\aiuser\Documents\Transport_MSSQL_AIplayground_OneIM_20260119_1451.zip -OutPath "C:/Test" -ConfigDir C:\DMWorkshop2\Config\Example -DMDll C:\Users\aiuser\Desktop\DeploymentManager-4.0.6-beta\Intragen.Deployment.OneIdentity.dll


# call Process
    ./MainPsModule.ps1 -Path C:\Users\aiuser\Documents\CCC_DM_Process.zip -OutPath "C:/Test" -ConfigDir C:\DMWorkshop2\Config\Example -DMDll C:\Users\aiuser\Desktop\DeploymentManager-4.0.6-beta\Intragen.Deployment.OneIdentity.dll


# call templates
  ./MainPsModule.ps1 -Path C:\Users\aiuser\Documents\GitHub\DM_test\CCC_Temp2.zip -OutPath "C:/" -ConfigDir C:\DMWorkshop2\Config\Example -DMDll C:\Users\aiuser\Desktop\DeploymentManager-4.0.6-beta\Intragen.Deployment.OneIdentity.dll


# Logger usage 
$Logger = Get-Logger # initialize Logger 

$Logger.Info("mpla mpla mpla")


# If I want to change the path of the log file, where logs are stored then I will change:
$debugLog.fileName with the appropriate path in Get-Logger function