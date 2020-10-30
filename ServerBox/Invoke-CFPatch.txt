[CmdletBinding()]
param
(
	[ValidateScript({ $_ -cmatch "Development|DevInt|Alpha" })]
	[Alias('env')]
	[string]$environment = "Development",
	[string]$patchPath = "\\isilon-hq-dfw\DevArchive\CF_Updates",
	[string]$patchName = "hf201600-301095.jar"
)

If ($environment -eq "") { Write-Output "You must provide an environment parameter!"; exit }

$xPath = "/Configuration/Environment[@Name=`"$environment`"]"
$environmentData = (Get-XMLFile -xmlFile "\\DevOps\Config\EQConfig.xml" | Select-Xml -XPath $xPath).get_node()

ForEach ($server in $environmentData.ColdFusion.Servers.Server) {
	$serverName = $server.Name
	#stop Coldfusion services
	$services = Get-Service -Name "Adobe CF201*" -ComputerName $serverName
	Stop-Service $services
	#copy update locally
	$instanceCount = [convert]::ToInt32($server.instanceCount, 10)
	$serverData = $environmentData.ColdFusion.Servers.Server | Where-Object { $_.Name -eq $serverName }
	For ($i = 0; $i -le $instanceCount; $i++) {
		If ($i -eq 0) {
			If (-not (Test-Path "\\$serverName\ServerBox\Servers\ColdFusion\cfusion\lib\updates")) { New-Item -Path "\\$serverName\ServerBox\Servers\ColdFusion\cfusion\lib\updates" -ItemType directory -Force }
			Copy-Item -Path "$patchPath\$patchName" -Destination "\\$serverName\ServerBox\Servers\ColdFusion\cfusion\lib\updates\$patchName" -Force
		} else {
			If (-not (Test-Path "\\$serverName\ServerBox\Servers\ColdFusion\cfusion$i\lib\updates")) { New-Item -Path "\\$serverName\ServerBox\Servers\ColdFusion\cfusion$i\lib\updates" -ItemType directory -Force }
			Copy-Item -Path "$patchPath\$patchName" -Destination "\\$serverName\ServerBox\Servers\ColdFusion\cfusion$i\lib\updates\$patchName" -Force
		}
	}
	#start them back up
	Start-Service $services
}