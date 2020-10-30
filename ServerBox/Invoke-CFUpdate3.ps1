[CmdletBinding()]
param
(
	[ValidateScript({ $_ -cmatch "Development|DevInt|Alpha|AlphaX7" })]
	[Alias('env')]
	[string]$environment = "Development"
)

If ($environment -eq "") { Write-Output "You must provide an environment parameter!"; exit }

$xPath = "/Configuration/Environment[@Name=`"$environment`"]"
$environmentData = (Get-XMLFile -xmlFile "\\DevOps\Config\EQConfig.xml" | Select-Xml -XPath $xPath).get_node()

ForEach ($server in $environmentData.ColdFusion.Servers.Server) {
	[System.Collections.Generic.List[System.Object]]$arrInstances = @("cfusion")
	$serverName = $server.Name
	#stop Coldfusion services
	$services = Get-Service -Name "Adobe CF201*" -ComputerName $serverName
	Stop-Service $services
	#copy update locally
	If (-not(Test-Path "\\$serverName\D$\Temp")){ New-Item -Path "\\$serverName\D$\Temp" -ItemType directory -Force }
	Copy-Item -Path "\\isilon-hq-dfw\DevArchive\CF_Updates\Update3\hotfix-003-300466.jar" -Destination "\\$serverName\D$\Temp\hotfix-003-300466.jar" -Force
	$propPath = "\\$serverName\D$\Temp\silent.properties"
	Copy-Item -Path "\\isilon-hq-dfw\DevArchive\CF_Updates\Update3\silent.properties" -Destination $propPath -Force
	$instanceCount = [convert]::ToInt32($server.instanceCount, 10)
	$serverData = $environmentData.ColdFusion.Servers.Server | Where-Object { $_.Name -eq $serverName }
	For ($i = 1; $i -le $instanceCount; $i++) {
		$arrInstances.Insert($i, "cfusion$i")
	}
	[string]$strList = "INSTANCE_LIST=cfusion"
	foreach ($instance in $arrInstances) {
		$strList = $strList + ",$instance"
	}
	(Get-Content $propPath).replace("INSTANCE_LIST=cfusion,cfusion1", $strList) | Set-Content $propPath
	Invoke-Command -ComputerName $serverName -ScriptBlock {
		Start-Process -FilePath "D:\ServerBox\Java\JDK\jdk1.8.0_92\jre\bin\java.exe" -ArgumentList "-jar D:\Temp\hotfix-003-300466.jar -i silent -f D:\Temp\silent.properties" -Wait
		Start-Process -FilePath "D:\ServerBox\Servers\ColdFusion\cfusion\runtime\bin\wsconfig.exe" -ArgumentList "-upgrade" -Wait
		Start-Service "Adobe CF*"
	}
}