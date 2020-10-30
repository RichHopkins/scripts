Stop-Service -Name ado*
$dirs = Get-ChildItem -Path "D:\ServerBox\Servers\ColdFusion\cf*" -Directory
foreach ($dir in $dirs) {
	$serverDir = $dir.FullName
	Robocopy "\\isilon-hq-dfw\DevArchive\CF_Updates" "$serverDir\hf-updates" /mir
}
$proc = New-Object -TypeName System.Diagnostics.Process
$proc.StartInfo.FileName = "D:\ServerBox\Java\JDK\jdk.1.8.0_151\bin\java.exe"
$proc.StartInfo.Arguments = "-jar D:\ServerBox\Servers\ColdFusion\cfusion\hf-updates\hotfix-007-311392.jar -i silent -f D:\ServerBox\Servers\ColdFusion\cfusion\hf-updates\hf-2016-0007-311392.properties"
$proc.StartInfo.UseShellExecute = $true
$proc.StartInfo.CreateNoWindow = $false
$proc.Start()
$proc.WaitForExit()
Start-Sleep -Seconds 30
Get-Process coldfusion | Stop-Process -Force
foreach ($dir in $dirs) {
	$serverDir = $dir.FullName
	Copy-Item -Path "\\isilon-hq-dfw\DevArchive\ServerBox\Servers\ColdFusion\cfusion\lib\tcnative-1.dll" -Destination "$serverDir\lib\tcnative-1.dll" -Force
	Copy-Item -Path "\\isilon-hq-dfw\DevArchive\ServerBox\Servers\ColdFusion\cfusion\lib\tcnative-1-src.pdb" -Destination "$serverDir\lib\tcnative-1-src.pdb" -Force
	Copy-Item -Path "D:\ServerBox\Servers\ColdFusion\cfusion\hf-updates\hf201600-301095.jar" -Destination "$serverDir\lib\updates\hf201600-301095.jar" -Force
	Copy-Item -Path "D:\ServerBox\Servers\ColdFusion\cfusion\hf-updates\hf201600-4197791.jar" -Destination "$serverDir\lib\updates\hf201600-4197791.jar" -Force
}
Start-Service ado*