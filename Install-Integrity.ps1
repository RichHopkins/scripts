Get-Process IntegrityClient -ErrorAction SilentlyContinue | Stop-Process
#uninstall current client
If (Test-Path "C:\Program Files (x86)\Integrity\IntegrityClient10\uninstall\IntegrityClientUninstall.exe") {
	Start-Process "C:\Program Files (x86)\Integrity\IntegrityClient10\uninstall\IntegrityClientUninstall.exe" -ArgumentList "-i silent" -Wait
}
If (Test-Path "C:\Program Files (x86)\Integrity\ILMClient11\uninstall\IntegrityClientUninstall.exe") {
	Start-Process "C:\Program Files (x86)\Integrity\ILMClient11\uninstall\IntegrityClientUninstall.exe" -ArgumentList "-i silent" -Wait
}
#final cleanup of old install
If (Test-Path "C:\Program Files (x86)\Integrity") {
	& CMD.EXE /C RMDIR /S /Q "C:\Program Files (x86)\Integrity"
}
#Run install and check the log for success
Start-Process "$PSScriptRoot\Integrity-11-2-Client-Win32\mksclient.exe" -Wait
If (-not(Test-Path "C:\Program Files (x86)\Integrity\ILMClient11\Integrity_Lifecycle_Manager_Client_11_Install_*.log")) {
	Write-Output "The PTC Integrity Client v.11.2 failed to install.  You may attempt to re-install the application inside of the Software Center.  If that does not succeed, please contact the Equator Help Desk for assistance."
	exit 1
} elseif (-not(Select-String -Path "C:\Program Files (x86)\Integrity\ILMClient11\Integrity_Lifecycle_Manager_Client_11_Install_*.log" -Pattern "Installation: Successful.")) {
	Write-Output "The PTC Integrity Client v.11.2 failed to install.  You may attempt to re-install the application inside of the Software Center.  If that does not succeed, please contact the Equator Help Desk for assistance."
	exit 1
} else {
	#install successful
}
#Install Patches
$patches = Get-ChildItem -Path "$PSScriptRoot\Integrity-11-2-CPS\client\*.zip"
foreach ($patch in $patches) {
	Start-Process -FilePath "C:\Program Files (x86)\Integrity\ILMClient11\bin\PatchClient.exe" $patch.FullName -Wait
}
#copy license file into place and update group policy
Copy-Item -Path "$PSScriptRoot\Integrity-11-2-Client-Win32\IntegrityClient.lax" -Destination "C:\Program Files (x86)\Integrity\ILMClient11\bin\IntegrityClient.lax" -Force
Start-Process "GPUPDATE" "/WAIT:0 /FORCE" -Wait