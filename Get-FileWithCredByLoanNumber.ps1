param
(
	[string]$sourcePath = "\\isilon\StageEXPORT\MoveIT\USBANK\Outgoing\cr1968469\ASPSUSBREOtoEQImport_Recon",
	[string]$destinationPath = "C:\Test",
	[string]$loanNumber = "4717863994",
	[string]$username = "",
	[string]$password = ""
)

[securestring]$secStringPassword = ConvertTo-SecureString $password -AsPlainText -Force
[pscredential]$credObject = New-Object System.Management.Automation.PSCredential ($username, $secStringPassword)
New-PSDrive -Name "Temp" -PSProvider "FileSystem" -Root $sourcePath -Credential $credObject | Out-Null
$files = Get-ChildItem "Temp:"
foreach ($file in $files) {
	if ((Get-Content -Path $file.FullName) -match $loanNumber) {
		Copy-Item -Path $file.FullName -Destination "$destinationPath\$($file.Name)"
	}
}