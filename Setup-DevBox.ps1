[CmdletBinding()]
param
(
	[switch]$skipIIS = $false,
	[switch]$installConnector = $true
)

[string]$devRoot = "C:\Development"
If (Test-Path $devRoot) {
	Write-Output "$devRoot found.  Please remove or rename it and try again."
	throw "This script is for new installs only."
}

If (-not (Test-Path -Path "C:\ProgramData\chocolatey\bin\choco.exe")) {
	Write-Output "Installing Chocolatey..."
	\\devops\Scripts\Install-Chocolatey.ps1
	Import-Module C:\ProgramData\chocolatey\helpers\chocolateyInstaller.psm1
	Update-SessionEnvironment
} elseif ([version](Get-Item "C:\ProgramData\chocolatey\bin\choco.exe").VersionInfo.FileVersion -lt [version]"0.10.5.0") {
	Write-Output "Old version of Chocolatey detected, please wait while it finishes upgrading..."
	choco source remove -n=devops
	choco source add -n=nexus -s="https://nexus.hq.reotrans.com/repository/nuget-hosted/" -priority=1 -y
	choco upgrade chocolatey -y
	Write-Output "Chocolatey upgraded."
}

Import-Module C:\ProgramData\chocolatey\helpers\chocolateyInstaller.psm1

If ($skipIIS) {
	Try {
		Import-Module WebAdministration
	} Catch {
		Write-Output "There was a problem importing the WebAdministration module.  Reinstalling IIS to make sure everything is ok."
		$skipIIS = $false
	}
}

If (!$skipIIS) {
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
}

choco install vcredist2012 -y -force
choco install vcredist2013 -y -force
choco install isapirewrite -y -force
choco install urlrewrite -y -force
choco install BeyondCompare3 -y -force
if ([System.Environment]::OSVersion.Version -lt (New-Object 'Version' 6,2)) {
	choco install vcredist2015 -y -force
}

If (-not (Test-Path "C:\Program Files\ConsoleZ\Console.exe")) {
	choco install ConsoleZ -y -force
}


#test for git
$gitTest = & git --version
if (!$gitTest -or $gitTest -ne "git version 2.25.0.windows.1") {
	choco install git -force -y -version 2.25.0
	$env:PATH += ";C:\Program Files\Git\bin"
}

Set-Location C:\
& git clone https://eqalm.hq.reotrans.com/bitbucket/scm/eqdo/devbox.git Development --depth 1

if (-not(Test-Path "$devRoot\Sandbox\DevSetup")) {
	Write-Output "Creating DevSetup directory $devRoot\Sandbox\DevSetup"
	New-Item "$devRoot\Sandbox\DevSetup" -ItemType directory | Out-Null
	Copy-item "$devRoot\Scripts\templates\DevSetup\Devsetup.cfc" "$devRoot\Sandbox\DevSetup"
	(Get-Content "$devRoot\Sandbox\DevSetup\DevSetup.cfc") -replace 'CHANGEYOUREMAIL', $env:username | Set-Content "$devRoot\Sandbox\DevSetup\DevSetup.cfc" -Force
}

#create Desktop shortcut with RunAsAdministratior flag enabled
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$($env:USERPROFILE)\Desktop\DevBox.lnk")
$Shortcut.TargetPath = "$devRoot\Scripts\DevBox.exe"
$Shortcut.Save()
$bytes = [System.IO.File]::ReadAllBytes("$($env:USERPROFILE)\Desktop\DevBox.lnk")
$bytes[0x15] = $bytes[0x15] -bor 0x20
[System.IO.File]::WriteAllBytes("$($env:USERPROFILE)\Desktop\DevBox.lnk", $bytes)

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

$scope = [EnvironmentVariableTarget]::Machine
$regPath = "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
$EnvironmentReg = Get-ItemProperty -Path $regPath
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
		choco install SublimeText -y -force
	}
}
Start-Process "$devRoot\Scripts\DevBox.exe" -Verb RunAs
Write-Output "DevBox Setup is Complete!"