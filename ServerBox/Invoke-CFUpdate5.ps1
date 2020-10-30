Stop-Service -Name ado*
Robocopy "\\isilon-hq-dfw\DevArchive\CF_Updates" "D:\ServerBox\Servers\ColdFusion\cfusion\hf-updates" /mir
$proc = New-Object -TypeName System.Diagnostics.Process
$proc.StartInfo.FileName = "D:\ServerBox\Java\JDK\jdk.1.8.0_151\bin\java.exe"
$proc.StartInfo.Arguments = "-jar D:\ServerBox\Servers\ColdFusion\cfusion\hf-updates\hotfix-005-303689.jar -i silent -f D:\ServerBox\Servers\ColdFusion\cfusion\hf-updates\hf-2016-0005-303689.properties"
$proc.StartInfo.UseShellExecute = $true
$proc.StartInfo.CreateNoWindow = $false
$proc.Start()
$proc.WaitForExit()
Start-Sleep -Seconds 30
Get-Process coldfusion | Stop-Process -Force
Start-Service ado*