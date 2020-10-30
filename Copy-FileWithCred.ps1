param
(
	[string]$source = "C:",
	[string]$destination = "\\TXV12APEQNP06.rtllc.local\d$",
	[string]$filename = "FNM2EQT_NewCase_Import_BETA.zip",
	[string]$username,
	[string]$password
)

[securestring]$secStringPassword = ConvertTo-SecureString $password -AsPlainText -Force
[pscredential]$credObject = New-Object System.Management.Automation.PSCredential ($username, $secStringPassword)
Try {
	New-PSDrive -Name "Temp" -PSProvider "FileSystem" -Root $destination -Credential $credObject -ErrorAction Stop | Out-Null
	Copy-Item -Path "$source\$filename" -Destination "Temp:$filename" -ErrorAction Stop
	Write-Output "$source\$filename was copied to $destination\$filename"
} Catch {
	Write-Output "Error Copying File!"
	Write-Output $_.Exception.Message
}