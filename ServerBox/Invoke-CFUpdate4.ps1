$servers = @("SERVERNAME1","SERVERNAME2")
foreach ($server in $servers) {
    Get-Service -Name ado* -ComputerName $server | Stop-Service
    $cfDirs = Get-ChildItem -Path "\\$server\ServerBox\Servers\ColdFusion" -Filter cfus* -Directory
    foreach ($dir in $cfDirs) {
		Robocopy \\isilon-hq-dfw\DevArchive\CF_Updates "$($dir.FullName)\hf_updates"
    }
    Get-Service -Name ado* -ComputerName $server | Start-Service
    Invoke-Command -ComputerName $server -ScriptBlock { Start-Process -FilePath "D:\ServerBox\Servers\ColdFusion\cfusion\runtime\bin\wsconfig.exe" -ArgumentList "-upgrade -ws IIS -site 0 -cluster cfcluster-$env:COMPUTERNAME -v" -Wait }
}