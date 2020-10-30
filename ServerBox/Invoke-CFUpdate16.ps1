#stop all services
Stop-Service -Name ado*
Stop-Service -Name W3SVC
#get list of cfusion folders
$dirs = Get-ChildItem -Path "D:\ServerBox\Servers\ColdFusion\cf*" -Directory
foreach ($dir in $dirs) {
	$serverDir = $dir.FullName
	#copy updates into place
	Robocopy "\\isilon-hq-dfw\DevArchive\CF_Updates" "$serverDir\hf-updates" /mir
}
#run the update and wait for it to end
$proc = New-Object -TypeName System.Diagnostics.Process
$proc.StartInfo.FileName = "D:\ServerBox\Java\JDK\jdk.1.8.0_151\bin\java.exe"
$proc.StartInfo.Arguments = "-jar D:\ServerBox\Servers\ColdFusion\cfusion\hf-updates\hotfix-016-320445.jar -i silent -f D:\ServerBox\Servers\ColdFusion\cfusion\hf-updates\hotfix-016-320445.properties"
$proc.StartInfo.UseShellExecute = $true
$proc.StartInfo.CreateNoWindow = $false
$proc.Start()
$proc.WaitForExit()
#give 30 seconds for CF to start up
Start-Sleep -Seconds 30
foreach ($dir in $dirs) {
	$serverDir = $dir.FullName
	#copy older patches into place
	Copy-Item -Path "D:\ServerBox\Servers\ColdFusion\cfusion\hf-updates\hf201600-301095.jar" -Destination "$serverDir\lib\updates\hf201600-301095.jar" -Force
	Copy-Item -Path "D:\ServerBox\Servers\ColdFusion\cfusion\hf-updates\hf201600-4197791.jar" -Destination "$serverDir\lib\updates\hf201600-4197791.jar" -Force
}
#stop CF process so services can start
Get-Process coldfusion | Stop-Process -Force
#upgrade IIS Connector
Start-Process -FilePath "D:\ServerBox\Servers\ColdFusion\cfusion\runtime\bin\wsconfig.exe" -ArgumentList "-upgrade" -Wait
#delete the backup files to save drive space
#foreach ($dir in (Get-ChildItem -Path "D:\ServerBox\Servers\ColdFusion\cfusi*\hf-updates\hf-*")) {
#	$updateDir = $dir.FullName
#	Remove-Item $updateDir -Recurse -Force
#}
#start back up
Start-Service ado*
Start-Service -Name W3SVC