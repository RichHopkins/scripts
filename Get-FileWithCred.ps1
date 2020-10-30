param
(
	[string]$destination = "\\TXV12APEQNP06.rtllc.local\d$",
	[string]$filename = "FNM2EQT_NewCase_Import_BETA.zip",
	[string]$username,
	[string]$password,
	[int]$loopcount
)

[securestring]$secStringPassword = ConvertTo-SecureString $password -AsPlainText -Force
[pscredential]$credObject = New-Object System.Management.Automation.PSCredential ($username, $secStringPassword)
New-PSDrive -Name "Temp" -PSProvider "FileSystem" -Root $destination -Credential $credObject | Out-Null
For ($i = 1; $i -le $loopcount; $i++) {
	If (Test-Path "Temp:$filename") {
		Write-Output "$destination\$filename exists"
		exit
	} elseif ($i = $loopcount -and -not (Test-Path "Temp:$filename")) {
		Write-Output "$destination\$filename not found after $i attempts"
	} else {
		Start-Sleep -Seconds 1
	}
}