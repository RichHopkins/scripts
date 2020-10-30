$checkDisk = Get-PSDrive C
If (($checkDisk.Free/1MB) -lt 1024) {
	Write-Warning "This upgrade requires at least 1GB of free disk space!"
	throw "Low Disk Space"
}

$question = Read-Host -Prompt "This process will take at least 15 to 30 minutes to complete.`nBE SURE TO CLOSE ALL OPEN APPLICATIONS BEFORE CONTINUING!!!`nType ""yes"" to continue"
Write-Output ""
If ($question -ine "yes") {
	throw "Quitting, user cancled."
}

If (Get-Process -Name "IntegrityClient" -ErrorAction SilentlyContinue) {
	Write-Output "Closing MKS Integrity..."
	Stop-Process -Name "IntegrityClient"
}

If (Get-Process -Name "DevBox" -ErrorAction SilentlyContinue) {
	Write-Output "Closing DevBox..."
	Stop-Process -Name "DevBox"
}

If (Get-Process -Name "coldfusion" -ErrorAction SilentlyContinue) {
	Write-Output "Closing Coldfusion 2016..."
	Stop-Process -Name "coldfusion"
}

If (Get-Process -Name "jrun" -ErrorAction SilentlyContinue) {
	Write-Output "Closing ColdFusion 9..."
	Stop-Process -Name "jrun"
}

If (Get-Process -Name "sublime_text" -ErrorAction SilentlyContinue) {
	Write-Output "Closing Sublime Text..."
	Stop-Process -Name "sublime_text"
}

$guid = [guid]::NewGuid()
$tempPath = "$env:TEMP\$guid"
Write-Output "Backing up C:\Development\Sandbox to $tempPath"
Write-Output ""
mkdir -Path $tempPath | Out-Null

Try {
	Move-Item -Path "C:\Development\Sandbox" -Destination $tempPath -Force -ErrorAction Stop
} Catch {
	Write-Warning "There was a problem backing up your sandboxes, attempting to restore them from`n$tempPath"
	Move-Item -Path "$tempPath\Sandbox\*" -Destination "C:\Development\Sandbox" -Force
	throw "Quitting.  Please reboot before trying again."
}

Write-Output "Deleting current setup..."
Write-Output ""
Do {
	& cmd /c rmdir C:\Development /s /q
} Until ((Test-Path "C:\Development") -eq $false)

Write-Output "Downloading new setup..."
Write-Output ""
Set-Location C:\
& git clone https://atlassian/bitbucket/scm/do/devbox.git Development

Write-Output ""
Write-Output "Putting Sandboxes back in place..."
Write-Output ""

Remove-Item -Path "C:\Development\Sandbox" -Force -Recurse
Move-Item -Path "$tempPath\Sandbox" -Destination "C:\Development" -Force

Write-Output "Setting up IIS Connector for ColdFusion 2016..."
& C:\Development\Servers\ColdFusion\cfusion\runtime\bin\wsconfig.exe -ws IIS -site 0 -v
Write-Output "Done!"
Start-Process -FilePath "C:\Development\Scripts\DevBox.exe"