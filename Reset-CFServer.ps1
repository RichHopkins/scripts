Get-Process cold* | Stop-Process -Force
& D:\ServerBox\Servers\ColdFusion\cfusion\bin\connectors\Remove_ALL_connectors.bat
$sites = Get-Website | Where-Object { $_.Name -ne "Default Web Site" }
if ($sites) {
	ForEach ($site in $sites) { Remove-Website $site.Name }
}
$services = Get-WmiObject -Class Win32_Service -Filter "Name LIKE 'Adobe CF%'"
if ($services) {
	$services.StopService() | Out-Null
	$services.Delete() | Out-Null
}
& cmd.exe /c "RMDIR /S /Q D:\ServerBox\Servers"
& cmd.exe /c "RMDIR /S /Q D:\ServerBox\Scripts"
Push-Location "IIS:\SslBindings"
Get-ChildItem | Remove-Item -Force
Pop-Location