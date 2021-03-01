function Get-ShortName
{
	param ($path)
	$fso = New-Object -ComObject Scripting.FileSystemObject
	If ($path.PSIsContainer)
	{
		$fso.GetFolder($path.FullName).ShortName
	}
	else
	{
		$fso.GetFile($path.FullName).ShortName
	}
}

#Upgrade java from the installation (Robocopy new version into place, or do you use the Java installer?)
robocopy "\\PATH\TO\NEW\JDK\jdk1.8.0_281" "D:\Java\JDK\jdk1.8.0_281" /e /mt
#Copy old cacerrs file into the new JDK
Copy-Item 'D:\Java\JDK\jdk.1.8.0_151\jre\lib\security\cacerts' 'D:\Java\JDK\jdk1.8.0_261\jre\lib\security\cacerts' -Force
#Search for all the occurance of older java version and replace it with the new version inside C:\Oracle\Middleware\Oracle_Home
$files = Get-ChildItem "C:\Oracle\Middleware\Oracle_Home" -File
foreach ($file in $files)
{
	if ((Get-Content $file) -match 'jdk.1.8.0_151')
	{
		#backup config before setting the new path
		Copy-Item -Path $file.FullName -Destination "$($file.FullName).bak" -Force
		(Get-Content $file).replace('jdk.1.8.0_151', 'jdk1.8.0_261') | Set-Content $file
	}
}
#Search for all the occurance of older java version and replace it with the new version inside C:\webdata (search for short name like JDK18~1.0_2)
$oldShortName = Get-ShortName -path (Get-Item 'D:\Java\JDK\jdk.1.8.0_151')
$newShortName = Get-ShortName -path (Get-Item 'D:\Java\JDK\jdk.1.8.0_281')
$files = Get-ChildItem "C:\webdata" -File
foreach ($file in $files)
{
	if ((Get-Content $file) -match $oldShortName)
	{
		#backup config before setting the new path
		Copy-Item -Path $file.FullName -Destination "$($file.FullName).bak" -Force
		(Get-Content $file).replace($oldShortName, $newShortName) | Set-Content $file
	}
}
#Go to C:\webdata\domains\Neogov\bin, run the setdomainenv.cmd script after installing the new java.
$status = Start-Process -FilePath "C:\webdata\domains\Neogov\bin\setdomainenv.cmd"
#If nodemanager fail to start, uninstall it. Run the uninstallnodemager to uninstall the nodemanager
#Check $status for error and execute uninstall if found
#Run installnodemanager to install the nodemanager