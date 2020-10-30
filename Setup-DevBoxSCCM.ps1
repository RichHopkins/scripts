#Install IIS
Write-Output "Feature: IIS-WebServerRole"
dism /online /Enable-Feature /FeatureName:IIS-WebServerRole /all
Write-Output "Feature: IIS-WebServer"
dism /online /Enable-Feature /FeatureName:IIS-WebServer /all
Write-Output "Feature: IIS-CommonHttpFeatures"
dism /online /Enable-Feature /FeatureName:IIS-CommonHttpFeatures /all
Write-Output "Feature: IIS-StaticContent"
dism /online /Enable-Feature /FeatureName:IIS-StaticContent /all
Write-Output "Feature: IIS-DefaultDocument"
dism /online /Enable-Feature /FeatureName:IIS-DefaultDocument /all
Write-Output "Feature: IIS-DirectoryBrowsing"
dism /online /Enable-Feature /FeatureName:IIS-DirectoryBrowsing /all
Write-Output "Feature: IIS-HttpErrors"
dism /online /Enable-Feature /FeatureName:IIS-HttpErrors /all
Write-Output "Feature: IIS-NetFxExtensibility"
dism /online /Enable-Feature /FeatureName:IIS-NetFxExtensibility /all
Write-Output "Feature: IIS-ISAPIExtensions"
dism /online /Enable-Feature /FeatureName:IIS-ISAPIExtensions /all
Write-Output "Feature: IIS-ISAPIFilter"
dism /online /Enable-Feature /FeatureName:IIS-ISAPIFilter /all
Write-Output "Feature: IIS-CGI"
dism /online /Enable-Feature /FeatureName:IIS-CGI /all
Write-Output "Feature: IIS-ASPNET"
dism /online /Enable-Feature /FeatureName:IIS-ASPNET /all
Write-Output "Feature: IIS-ServerSideIncludes"
dism /online /Enable-Feature /FeatureName:IIS-ServerSideIncludes /all
Write-Output "Feature: IIS-HttpLogging"
dism /online /Enable-Feature /FeatureName:IIS-HttpLogging /all
Write-Output "Feature: IIS-RequestMonitor"
dism /online /Enable-Feature /FeatureName:IIS-RequestMonitor /all
Write-Output "Feature: IIS-Security"
dism /online /Enable-Feature /FeatureName:IIS-Security /all
Write-Output "Feature: IIS-BasicAuthentication"
dism /online /Enable-Feature /FeatureName:IIS-BasicAuthentication /all
Write-Output "Feature: IIS-WindowsAuthentication"
dism /online /Enable-Feature /FeatureName:IIS-WindowsAuthentication /all
Write-Output "Feature: IIS-RequestFiltering"
dism /online /Enable-Feature /FeatureName:IIS-RequestFiltering /all
Write-Output "Feature: IIS-HttpCompressionStatic"
dism /online /Enable-Feature /FeatureName:IIS-HttpCompressionStatic /all
Write-Output "Feature: IIS-HttpCompressionDynamic"
dism /online /Enable-Feature /FeatureName:IIS-HttpCompressionDynamic /all
Write-Output "Feature: IIS-WebServerManagementTools"
dism /online /Enable-Feature /FeatureName:IIS-WebServerManagementTools /all
Write-Output "Feature: IIS-ManagementConsole"
dism /online /Enable-Feature /FeatureName:IIS-ManagementConsole /all
Write-Output "Feature: IIS-ManagementScriptingTools"
dism /online /Enable-Feature /FeatureName:IIS-ManagementScriptingTools /all
Write-Output "Feature: IIS-ManagementService"
dism /online /Enable-Feature /FeatureName:IIS-ManagementService /all
Write-Output "Feature: IIS-IIS6ManagementCompatibility"
dism /online /Enable-Feature /FeatureName:IIS-IIS6ManagementCompatibility /all
Write-Output "Feature: IIS-Metabase"
dism /online /Enable-Feature /FeatureName:IIS-Metabase /all
Write-Output "Feature: IIS-WMICompatibility"
dism /online /Enable-Feature /FeatureName:IIS-WMICompatibility /all

#Install C++ Runtimes
& \\hq\eq\Software\Resources\DevOps\Packages\vcredist2012_x64.exe /quiet /norestart
& \\hq\eq\Software\Resources\DevOps\Packages\vcredist2013_x64.exe /Q /noreboot

#Install ConsoleZ
Expand-Archive -Path "\\hq\eq\Software\Resources\DevOps\Packages\ConsoleZ.x64.1.19.0.19104.zip" -DestinationPath "C:\Program Files\ConsoleZ" -Force
 
#test for git
$gitTest = & git --version
if (!$gitTest -or $gitTest -ne "git version 2.24.1.windows.2") {
	choco install git -force -y -version 2.24.1.2
	$env:Path += "; C:\Program Files\Git\bin"
}

Set-Location C:\
& git clone https://eqalm.hq.reotrans.com/bitbucket/scm/do/devbox.git Development

if (-not(Test-Path "$devRoot\Sandbox\DevSetup")) {
	Write-Output "Creating DevSetup directory $devRoot\Sandbox\DevSetup"
	New-Item "$devRoot\Sandbox\DevSetup" -ItemType directory | Out-Null
	Copy-item "$devRoot\Scripts\templates\DevSetup\Devsetup.cfc" "$devRoot\Sandbox\DevSetup"
	(Get-Content "$devRoot\Sandbox\DevSetup\DevSetup.cfc") -replace 'CHANGEYOUREMAIL', $env:username | Set-Content "$devRoot\Sandbox\DevSetup\DevSetup.cfc" -Force
}

#create Desktop shortcut with RunAsAdministratior flag enabled
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$Home\Desktop\DevBox.lnk")
$Shortcut.TargetPath = "$devRoot\Scripts\DevBox.exe"
$Shortcut.Save()
$bytes = [System.IO.File]::ReadAllBytes("$Home\Desktop\DevBox.lnk")
$bytes[0x15] = $bytes[0x15] -bor 0x20
[System.IO.File]::WriteAllBytes("$Home\Desktop\DevBox.lnk", $bytes)

& netsh advfirewall firewall add rule name="Adobe ColdFusion" dir=in action=allow program="$devRoot\Servers\ColdFusion\cfusion\bin\coldfusion.exe" enable=yes
Start-Process "C:\Program Files\ConsoleZ\Console.exe" -ArgumentList " -t CMD -r ""/C $devRoot\Servers\ColdFusion\cfusion\bin\cfstart.bat""" -Verb RunAs

if (-not (Test-Path "$devRoot\Sandbox\_AllSites")) {
	New-Item "$devRoot\Sandbox\_AllSites" -ItemType directory | Out-Null
}
Copy-item $devRoot\Scripts\templates\AllSites\index.cfm "$devRoot\Sandbox\_AllSites" -Force
Copy-item $devRoot\Scripts\templates\AllSites\web.config "$devRoot\Sandbox\_AllSites" -Force

if (-not ((get-website | where-object { $_.name -eq "AllSites.eqlocal" }).name)) {
	New-Website -name "AllSites.eqlocal" -HostHeader "AllSites.eqlocal" -PhysicalPath "$devRoot\Sandbox\_AllSites" -force | Out-Null
	New-WebVirtualDirectory -site "AllSites.eqlocal" -Name "CFIDE" -PhysicalPath "$devRoot\Servers\ColdFusion\cfusion\wwwroot\CFIDE" | Out-Null
}

Write-Output "Waiting 30 seconds for ColdFusion to finish starting..."
Start-Sleep -Seconds 30
Write-Output "Setting up the IIS ColdFusion Connector..."
Start-Process "$devRoot\Servers\ColdFusion\cfusion\runtime\bin\wsconfig.exe" -ArgumentList " -ws IIS -site 0 -v" -Verb RunAs
& cmd.exe /c %windir%\system32\inetsrv\appcmd.exe set config /section:staticContent /-"[fileExtension='.air', mimeType='application/vnd.adobe.air-application-installer-package+zip']"
& cmd.exe /c %windir%\system32\inetsrv\appcmd.exe set config /section:staticContent /-"[fileExtension='.woff', mimeType='application/woff']"
& cmd.exe /c %windir%\system32\inetsrv\appcmd.exe set config /section:staticContent /+"[fileExtension='.woff', mimeType='application/woff']"
& cmd.exe /c %windir%\system32\inetsrv\appcmd.exe set config /section:staticContent /-"[fileExtension='.woff2', mimeType='application/woff2']"
& cmd.exe /c %windir%\system32\inetsrv\appcmd.exe set config /section:staticContent /+"[fileExtension='.woff2', mimeType='application/woff2']"
If ($EnvironmentReg.JAVA_HOME -ne "C:\Development\Java\JDK\jdk1.8.0_151") {
	[Environment]::SetEnvironmentVariable("JAVA_HOME", "C:\Development\Java\JDK\jdk1.8.0_151", $scope)
}
If ($EnvironmentReg.M2_HOME -ne "C:\Development\Utilities\apache-maven") {
	[Environment]::SetEnvironmentVariable("M2_HOME", "C:\Development\Utilities\apache-maven", $scope)
}
$Path = $EnvironmentReg.PATH
If (!($Path | Select-String -Pattern 'C:\Development\Java\JDK\jdk1.8.0_151\jre\bin' -SimpleMatch)) {
	[Environment]::SetEnvironmentVariable("PATH", "C:\Development\Java\JDK\jdk1.8.0_151\jre\bin;$Path", $scope)
	$EnvironmentReg = Get-ItemProperty -Path $regPath
}
If (!($Path | Select-String -Pattern 'C:\Development\Utilities\apache-maven' -SimpleMatch)) {
	[Environment]::SetEnvironmentVariable("PATH", "$Path;C:\Development\Utilities\apache-maven", $scope)
	$EnvironmentReg = Get-ItemProperty -Path $regPath
}
If (-not (Test-Path "C:\Windows\System32\sqljdbc_auth.dll")) {
	If (Test-Path "\\HQ\EQ\Software\Resources\DevOps\DevBox\Utilities\sqljdbc_auth.dll") {
		Copy-Item -Path "\\HQ\EQ\Software\Resources\DevOps\DevBox\Utilities\sqljdbc_auth.dll" -Destination "C:\Windows\System32\sqljdbc_auth.dll" -Force
	}
}
If (-not (Test-Path "C:\Program Files\Sublime Text 3\sublime_text.exe")) {
	$MyADGroups = (New-Object System.DirectoryServices.DirectorySearcher("(&(objectCategory=User)(samAccountName=$($env:username)))")).FindOne().GetDirectoryEntry().memberOf
	If ($MyADGroups -match 'Sublime.Text') {
		Write-Output "Sublime Text 3 not found."
		Write-Output "Please see this page for details on how to install it... https://eqalm.hq.reotrans.com/confluence/display/DO/Sublime+Text+3"
	}
}
Start-Process "$devRoot\Scripts\DevBox.exe" -Verb RunAs
Write-Output "DevBox Setup is Complete!"