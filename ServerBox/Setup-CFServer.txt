[CmdletBinding()]
param
(
	[ValidateSet('Development', 'DevInt', 'Alpha', 'AlphaX7', 'Beta', 'BetaX', 'Performance', 'REM', 'Stage', 'Production', 'Performance','Consumer')]
	[Alias('env')]
	[string]$environment = "",
	[string]$serverName = $env:COMPUTERNAME
)

#region Initial Checks
#Validate environment not empty or null
if ($environment -eq "") {
	throw "You must provide a environment parameter to the script!"
}

#Install C++ Runtimes
& \\hq\eq\Software\Resources\DevOps\Packages\vcredist2012_x64.exe /quiet /norestart

#Verify PSModulePath
if (($env:PSModulePath -match "C:\\Program Files\\WindowsPowerShell\\Modules") -eq $false) {
	$env:PSModulePath = $env:PSModulePath + ";C:\Program Files\WindowsPowerShell\Modules"
}

#Install eqDevOps
If (-not (Test-Path "C:\Program Files\WindowsPowerShell\Modules\eqDevOps")) {
	Copy-Item "\\hq\eq\Software\Resources\DevOps\eqDevOps" "C:\Program Files\WindowsPowerShell\Modules\eqDevOps" -Container -Recurse -Force
}

#Install Carbon
If (-not (Test-Path "C:\Program Files\WindowsPowerShell\Modules\Carbon")) {
	Copy-Item "\\hq\eq\Software\Resources\DevOps\Carbon" "C:\Program Files\WindowsPowerShell\Modules\Carbon" -Container -Recurse -Force
}
#endregion

#region Script Setup
Add-Type @'
public class ColdFusionInstance
{
    public string name = null;
	public string dirName = null;
	public string binaryPathName = null;
	public int shutdownPort = 0;
	public int connectorHTTPPort = 0;
	public int connectorAJPPort = 0;
	public int connectorRedirectPort = 0;
	public int receiverPort = 0;
	public int seeFusionPort = 0;
	public int jettyPort = 0;
}
'@

Add-Type @'
public class WebSite
{
    public string name = null;
	public string path = null;
	public string ipAddress = null;
}
'@

Add-Type -AssemblyName System.IO.Compression.FileSystem

If (-not (Get-Module eqDevOps)) {
	Import-Module eqDevOps
}
If (-not (Get-Module Carbon)) {
	Import-Module Carbon
}

#select Environment node from ServerBoxConfigData.xml
$xPath = "/Environment[@Name=`"$environment`"]"
$environmentData = (Get-XMLFile -xmlFile "\\DevOps\Config\$($environment)Config.xml" | Select-Xml -XPath $xPath).get_node()
$serverData = $environmentData.ColdFusion.Servers.Server | Where-Object { $_.Name -eq $serverName }
[string]$RABBITMQIPADDRESS = $serverData.RABBITMQIPADDRESS
[int]$instanceCount = [convert]::ToInt32($serverData.instanceCount, 10)
[string]$siteSourcePath = $environmentData.ColdFusion.CFConfig.SourcePath
[string]$ServerBoxSourcePath = $environmentData.ColdFusion.ServerBoxConfig.SourcePath
[string]$ServerBoxInstancePath = $environmentData.ColdFusion.ServerBoxConfig.InstancePath
[string]$cfConfigFiles = $environmentData.ColdFusion.ServerBoxConfig.ConfigSourcePath
[string]$rootPath = $environmentData.ColdFusion.ServerBoxConfig.DestinationPath
[string]$ELKDir = Join-Path -Path $rootPath -ChildPath "ELK"
[string]$webRoot = $environmentData.ColdFusion.CFConfig.DestinationPath
[string]$ImagesPath = $environmentData.ColdFusion.CFConfig.ImagesPath
[string]$serverDir = Join-Path -Path $rootPath -ChildPath "Servers\ColdFusion"
[string]$svcAccount = $environmentData.ColdFusion.CFConfig.svcAccount
[string]$clusterName = "cfcluster-$env:COMPUTERNAME"
[string]$DalClient = $environmentData.ColdFusion.CFConfig.DalClient
[string]$SeeFusionServer = $environmentData.ColdFusion.CFConfig.seeFusion
$key = Get-Content "\\devops\Config\AES.key"
$svcAcct = $svcAccount -replace '@hq.reotrans.com',''
$svcPass = Get-Content "\\devops\Config\$svcAcct.txt" | ConvertTo-SecureString -Key $key
$svcCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $svcAccount, $svcPass
[string]$svcPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($svcPass))
$seePass = Get-Content "\\devops\Config\cf.reotrans.$($environment.ToLower()).txt" | ConvertTo-SecureString -Key $key
[string]$seePassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($seePass))
#endregion

#region Initial Server Setup
#Setup service login rights for service account
If ((Test-Privilege -Identity $svcAccount -Privilege SeServiceLogonRight) -eq $false) {
	Grant-Privilege -Identity $svcAccount -Privilege SeServiceLogonRight | Out-Null
}

#Copy ServerBox locally
Write-Output "Copying $ServerBoxSourcePath to $rootPath"
If (-not (Test-Path $rootPath\Logs)) { New-Item -Path "$rootPath\Logs" -ItemType directory }
Robocopy $ServerBoxSourcePath $rootPath /mt /e /LOG+:"$rootPath\Logs\serverbox.log"
Copy-Item -Path "$cfConfigFiles\CertStores\$environment\cacerts" -Destination "$rootPath\Java\JDK\jdk1.8.0_92\jre\lib\security\cacerts" -Force
Copy-Item -Path "$cfConfigFiles\CertStores\$environment\EquatorKeyStore" -Destination "$rootPath\Certs\KeyStores\EquatorKeyStore" -Force
Copy-Item -Path "$cfConfigFiles\CertStores\$environment\EquatorTrustStore" -Destination "$rootPath\Certs\TrustStores\EquatorTrustStore" -Force
#copies neo files
Copy-Item -Path "$cfConfigFiles\$environment\*" -Destination "$serverDir\cfusion\" -Container -Recurse -Force
#update neo-metric.xml cfconnectorport
Edit-StringInFile -filePath "$serverDir\cfusion\lib\neo-metric.xml" -oldString "8501" -newString "8500"
#update neo-runtime.xml paths
Edit-StringInFile -filePath "$serverDir\cfusion\lib\neo-runtime.xml" -oldString "cfusion1" -newString "cfusion"
Write-Output "Copying $siteSourcePath to $webRoot"
robocopy $siteSourcePath $webRoot /mt /mir /LOG+:"$rootPath\Logs\wwwroot.log"
& cmd.exe /c mklink /d /j "$serverDir\cfusion\lib\Equator" "$webRoot\ThirdPartyTools\Equator"
New-Service -Name "Adobe CF2016" -BinaryPathName "$serverDir\cfusion\bin\coldfusionsvc.exe" -DisplayName "Adobe CF2016" -Description "Adobe CF2016" -StartupType Manual -Credential $svcCred | Out-Null
#endregion

#region Setup Coldfusion
function Add-CFInstanceObj ($i) {
	$temp = New-Object ColdFusionInstance
	$temp.name = "Adobe CF2016 $i"
	$temp.dirName = "cfusion$i"
	$temp.binaryPathName = "$serverDir\cfusion$i\bin\coldfusionsvc.exe"
	$temp.shutdownPort = 8007 + $i - 1
	$temp.connectorHTTPPort = 8501 + $i - 1
	$temp.connectorAJPPort = 8051 + $i - 1
	$temp.connectorRedirectPort = 8445 + $i - 1
	$temp.receiverPort = 4001 + $i - 1
	$temp.seeFusionPort = 9000 - $i
	$temp.jettyPort = 5501 + $i - 1
	return [ColdFusionInstance]$temp
}

function Add-CFInstance ([ColdFusionInstance] $cfInstance)
{
	$instanceName = $cfInstance.dirName

	#unzip cfusion.zip
	[System.IO.Compression.ZipFile]::ExtractToDirectory("$serverDir\cfusion.zip", "$serverDir\$instanceName")

	#copy config files down
	Copy-Item -Path "$cfConfigFiles\$environment\*" -Destination "$serverDir\$instanceName\" -Container -Recurse -Force

	#create symlink
	& cmd.exe /c mklink /d /j "$serverDir\$instanceName\lib\Equator" "$webRoot\ThirdPartyTools\Equator"

	#update jvm.config path
	Edit-StringInFile -filePath "$serverDir\$instanceName\bin\jvm.config" -oldString "cfusion1" -newString $instanceName

	#update port.properties
	#Edit-StringInFile -filePath "$serverDir\$instanceName\bin\port.properties" -oldString "8011" -newString $cfInstance.shutdownPort.ToString()

	#update neo-metric.xml cfconnectorport
    Edit-StringInFile -filePath "$serverDir\$instanceName\lib\neo-metric.xml" -oldString "8501" -newString $cfInstance.connectorHTTPPort.ToString()

	#update neo-runtime.xml paths
    Edit-StringInFile -filePath "$serverDir\$instanceName\lib\neo-runtime.xml" -oldString "cfusion1" -newString $instanceName

	#setup SeeFusion
	$ServerIP = ([System.Net.Dns]::GetHostAddresses($computerName)).IPAddressToString | Where-Object { $_ -ne '::1' }
	Edit-StringInFile -filePath "$serverDir\$instanceName\wwwroot\WEB-INF\classes\seefusion.properties" -oldString "sqlServerName" -newString "$SeeFusionServer"
	Edit-StringInFile -filePath "$serverDir\$instanceName\wwwroot\WEB-INF\classes\seefusion.properties" -oldString "sqlPassword" -newString "$seePassword"
	Edit-StringInFile -filePath "$serverDir\$instanceName\wwwroot\WEB-INF\classes\seefusion.properties" -oldString "ipValue" -newString "$ServerIP"
	Edit-StringInFile -filePath "$serverDir\$instanceName\wwwroot\WEB-INF\classes\seefusion.properties" -oldString "PortNumber" -newString $cfInstance.seeFusionPort.ToString()
	Edit-StringInFile -filePath "$serverDir\$instanceName\wwwroot\WEB-INF\classes\seefusion.properties" -oldString "ServerName" -newString "$serverName-$instanceName"

	#update jetty.xml
	Edit-StringInFile -filePath "$serverDir\$instanceName\lib\jetty.xml" -oldString "5501" -newString $cfInstance.jettyPort.ToString()
	#$jetty = Get-XMLFile -xmlFile "$serverDir\$instanceName\lib\jetty.xml"
	#$jettyPort = (Select-Xml -Xml $jetty -XPath "/Configure/Call/Arg/New/Set[@name='port']").get_node()
	#$jettyPort.InnerText = $cfInstance.jettyPort.ToString()
	#Set-XMLFile -xmlFile "$serverDir\$instanceName\lib\jetty.xml" -xmlData $jetty

	#update server.xml
    Edit-StringInFile -filePath "$serverDir\$instanceName\runtime\conf\server.xml" -oldString "8012" -newString $cfInstance.connectorAJPPort.ToString()
	Edit-StringInFile -filePath "$serverDir\$instanceName\runtime\conf\server.xml" -oldString "8007" -newString $cfInstance.shutdownPort.ToString()
	Edit-StringInFile -filePath "$serverDir\$instanceName\runtime\conf\server.xml" -oldString "8501" -newString $cfInstance.connectorHTTPPort.ToString()
	Edit-StringInFile -filePath "$serverDir\$instanceName\runtime\conf\server.xml" -oldString "8445" -newString $cfInstance.connectorRedirectPort.ToString()
	Edit-StringInFile -filePath "$serverDir\$instanceName\runtime\conf\server.xml" -oldString "cfusion1" -newString $instanceName
	Edit-StringInFile -filePath "$serverDir\$instanceName\runtime\conf\server.xml" -oldString "4001" -newString $cfInstance.receiverPort.ToString()

	#check cluster.xml
	$clusterData = Get-XMLFile -xmlFile "$serverDir\config\cluster.xml"
	if (-not ($clusterData.clusters.cluster.server -match $instanceName))
	{
		$oldServer = (Select-Xml -Xml $clusterData -XPath "/clusters/cluster/server[last()]").get_node()
		$newServer = $clusterData.CreateElement("server")
		$newServer.InnerText = $instanceName
		$clusterData.clusters.cluster.InsertAfter($newServer, $oldServer)
		Set-XMLFile -xmlFile "$serverDir\config\cluster.xml" -xmlData $clusterData
	}

	#update instances.xml
	$instanceData = Get-XMLFile -xmlFile "$serverDir\config\instances.xml"
	if (-not ($instanceData.servers.server.name -match $instanceName))
	{
		$oldServer = (Select-Xml -Xml $instanceData -XPath "/servers/server[last()]").get_node()
		$newServer = $instanceData.CreateElement("server")
		$newServerName = $instanceData.CreateElement("name")
		$newServerName.InnerText = $instanceName
		$newServerDir = $instanceData.CreateElement("directory")
		$newServerDir.InnerText = "$serverDir\$instanceName"
		$newServer.AppendChild($newServerName)
		$newServer.AppendChild($newServerDir)
		$instanceData.servers.InsertAfter($newServer, $oldServer)
		Set-XMLFile -xmlFile "$serverDir\config\instances.xml" -xmlData $instanceData
	}
}

function Add-CFWindowsService ([ColdFusionInstance] $cfInstance) {
	New-Service -Name $cfInstance.name -BinaryPathName $cfInstance.binaryPathName -DisplayName $cfInstance.name -Description $cfInstance.name -StartupType Automatic -Credential $svcCred | Out-Null
}

#setup cluster.xml
$clusterData = Get-XMLFile -xmlFile "$serverDir\config\cluster.xml"
$clusterData.clusters.cluster.name = $clusterName
Set-XMLFile -xmlFile "$serverDir\config\cluster.xml" -xmlData $clusterData

for ($i = 1; $i -le $instanceCount; $i++) {
	[ColdFusionInstance]$cfInstance = Add-CFInstanceObj $i
	Add-CFInstance $cfInstance
	If (-not (Get-Service "Adobe CF2016 $i" -ErrorAction SilentlyContinue)) {
		Add-CFWindowsService $cfInstance
	} else {
		Write-Output "Service Adobe CF2016 $i already exists."
	}
}

for ($i = 1; $i -le $instanceCount; $i++) {
	Start-Service "Adobe CF2016 $i"
}

#endregion

#region Setup Websites
function Add-WebSiteObject([System.Xml.XmlElement]$website) {
	$temp = New-Object WebSite
	$temp.name = $website.Name
	$temp.ipAddress = $website.ipAddress
	switch -regex ($website.Name) {
		"csa" { $temp.path = "$webRoot\csa" }
		"ws|www" { $temp.path = "$webRoot\oms" }
		"investors" { $temp.path = "$webRoot\public" }
		"webservices" { $temp.path = "$webRoot\webservices" }
		"api" {$temp.path = "$webRoot\api"}
		"images" { $temp.path = $ImagesPath }
		default { $temp.path = "$webRoot\v5" }
	}
	return [WebSite]$temp
}

function Add-WebSite([WebSite]$site) {
	$siteName = $site.name
	switch ($environment) {
		Development { $certName = '*.devagl.eqdev' }
		DevInt { $certName = '*.devint.eqdev' }
		Alpha { $certName = '*.alpha.eqdev' }
		AlphaX7 { $certName = '*.alphax.eqdev' }
		default { $certName = $siteName }
	}
	$websitePhysicalPath = $site.path
	$ipAddress = $site.ipAddress

	if (Test-Path $websitePhysicalPath) {
		if (Get-Website -Name $siteName) {
			try {
				Remove-Website $siteName
			} catch {
				Write-Output "Could not remove website $siteName."
			}
		}

		#get cert and thumbprint for ssl bindings
		$cert = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.FriendlyName -eq $certName }
		$thumb = $cert.Thumbprint.ToString()
		#create site and ssl bindings
		New-Website -Name $siteName -PhysicalPath $websitePhysicalPath -IPAddress $ipAddress | Out-Null
		if ($cert) {
			Push-Location IIS:\SslBindings
			New-WebBinding -Name $siteName -IPAddress $ipAddress -Port 443 -Protocol https | Out-Null
			Get-Item cert:\LocalMachine\My\$thumb | New-Item "$ipAddress!443"
			Pop-Location
		}
		New-WebVirtualDirectory -site $siteName -Name "/ajax" -PhysicalPath "$webRoot\ajax" | Out-Null
		New-WebVirtualDirectory -site $siteName -Name "/cfc" -PhysicalPath "$webRoot\cfc" | Out-Null
		New-WebVirtualDirectory -site $siteName -Name "/health" -PhysicalPath "$webRoot\health" | Out-Null
		New-WebVirtualDirectory -site $siteName -Name "/scheduledtasks" -PhysicalPath "$webRoot\scheduledtasks" | Out-Null
		New-WebVirtualDirectory -site $siteName -Name "/scripts" -PhysicalPath "$webRoot\scripts" | Out-Null
		#Add if for webservices that points to v5webservices
		New-WebVirtualDirectory -site $siteName -Name "/webservices" -PhysicalPath "$webRoot\webservices" | Out-Null
		New-WebVirtualDirectory -site $siteName -Name "/v5" -PhysicalPath "$webRoot\v5" | Out-Null
		if ($siteName -match "images") {
			$imageSite = Get-Item "IIS:\Sites\$siteName"
			$imageSite.virtualDirectoryDefaults.userName = "hq\$svcAcct"
			$imageSite.virtualDirectoryDefaults.password = $svcPassword
			$imageSite | set-item
		}
		if ($siteName -match "consumer") {
			#install URL Rewrite
		}
	}
}

#create sites
if ($serverData.Website) {
	ForEach ($website in $serverData.Website) {
		$site = Add-WebSiteObject $website
		Add-WebSite -site $site
	}
}
#endregion

#region Setup IIS Connector
Write-Output "Setting up the IIS ColdFusion Connector..."
& $serverDir\cfusion\runtime\bin\wsconfig.exe -ws IIS -site 0 -cluster $clusterName -v
#endregion

#region Smoketest Websites
#Modifying HOSTS file for local smoke tests
$sites = Get-Website | Where-Object { $_.Name -ne "Default Web Site" }
ForEach ($site in $sites) {
	$bindings = $site.Bindings.Collection.bindingInformation -split ":"
	Set-HostsEntry -IPAddress $bindings[0] -HostName $site.Name -Description "For local smoke tests"
}

#run smoketests
$sites = Get-Website | Where-Object { $_.Name -ne "Default Web Site" }
ForEach ($site in $sites) {
	$website = $site.Name
	$smoketest = Invoke-WebRequest -Uri "http://$website/health/status.cfm"
	if ($smoketest.AllElements.innerHTML -contains "Live") {
		write-output "Smoke test on $website was successful!"
	} else {
		write-output "Smoke test on $website failed!"
	}
}
#endregion

#region Setup ELK
#Install-NXLog
New-Service -Name "nxlog" -BinaryPathName "$ELKDir\nxlog\nxlog.exe -c $ELKDir\nxlog\conf\nxlog.conf" -DisplayName "nxlog" -Description "nxlog" -StartupType Automatic | Out-Null
# Install-nssm
set-location $ELKDir\nssm-2.24\win64
.\nssm install LogStash152-Shipper "$ELKDir\logstash-1.5.2\bin\logstash.bat"
.\nssm set LogStash152-Shipper AppParameters agent -f logstash-rabbitmq-shipper.conf
.\nssm set LogStash152-Shipper AppStdout $ELKDir\logstash-1.5.2\logs\logstash.out
.\nssm set LogStash152-Shipper AppStderr $ELKDir\logstash-1.5.2\logs\logstash.err
#Edit-nxlog-file
Edit-StringInFile -filePath "$ELKDir\nxlog\conf\nxlog.conf" -oldString "NXLOGHOST" -newString $env:Computername
#Edit-ShipperConf
Edit-StringInFile -filePath "$ELKDir\logstash-1.5.2\bin\logstash-rabbitmq-shipper.conf" -oldString 'RABBITMQIPADDRESS' -newString $RABBITMQIPADDRESS
#endregion
