If (Get-Process -Name cold* -ErrorAction SilentlyContinue) { Stop-Process -Name cold* }
If (Get-Process -Name DevBox -ErrorAction SilentlyContinue) { Stop-Process -Name DevBox }
$filelist = @("C:\Development\Servers\ColdFusion\cfusion\bin\port.properties",
	"C:\Development\Servers\ColdFusion\cfusion\lib\client.properties",
	"C:\Development\Servers\ColdFusion\cfusion\lib\license.properties",
	"C:\Development\Servers\ColdFusion\cfusion\logs\application.log",
	"C:\Development\Servers\ColdFusion\cfusion\logs\audit.log",
	"C:\Development\Servers\ColdFusion\cfusion\wwwroot\WEB-INF\cfform\logs\flex.log",
    	"C:\Development\Servers\ColdFusion\cfusion\lib\*.bak")
foreach ($file in $filelist) {
	If (Test-Path $file) {
		Remove-Item -Path $file -Force | Out-Null
	}
}
Set-Location "C:\Development"
& git fetch origin
& git reset --hard HEAD
& git pull
Start-Process "C:\Development\Scripts\DevBox.exe"