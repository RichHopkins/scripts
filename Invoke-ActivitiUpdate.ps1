[CmdletBinding()]
param
(
	[ValidateSet('Development', 'DevInt', 'Alpha', 'AlphaX7', 'Beta', 'BetaX', 'Performance', 'REM', 'Stage', 'Production', 'Performance', 'Consumer')]
	[Alias('env')]
	[string]$environment = "",
	[string]$serverName = $env:COMPUTERNAME
)

Add-Type -Assembly System.IO.Compression.FileSystem
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

Import-Module eqDevOps
Import-Module Carbon

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

function Edit-CFInstance {
	param
	(
		[ColdFusionInstance]$cfInstance
	)
	
	$instanceName = $cfInstance.dirName

	#Replace context.xml
	Copy-Item -Path "$serverDir\$instanceName\runtime\conf\context.xml" -Destination "$serverDir\$instanceName\runtime\conf\context.xml.bak" -Force
	Copy-Item -Path "$ServerBoxSourcePath\Servers\Coldfusion\cfusion\runtime\conf\context.xml" -Destination "$serverDir\$instanceName\runtime\conf\context.xml" -Force
	
	#Replace server.xml and set it back up
	Copy-Item -Path "$serverDir\$instanceName\runtime\conf\server.xml" -Destination "$serverDir\$instanceName\runtime\conf\server.xml.bak" -Force
	$zip = [System.IO.Compression.ZipFile]::OpenRead($sourceFile)
	$zip.Entries | Where-Object { $_.Name -eq 'server.xml' } | ForEach-Object { [System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, "$serverDir\$instanceName\runtime\conf\server.xml", $true) }
	$zip.Dispose()
	#Copy-Item -Path "\\isilon-hq-dfw\DevArchive\temp\server.xml" -Destination "$serverDir\$instanceName\runtime\conf\server.xml" -Force
	Edit-StringInFile -filePath "$serverDir\$instanceName\runtime\conf\server.xml" -oldString "8051" -newString $cfInstance.connectorAJPPort.ToString()
	Edit-StringInFile -filePath "$serverDir\$instanceName\runtime\conf\server.xml" -oldString "8007" -newString $cfInstance.shutdownPort.ToString()
	Edit-StringInFile -filePath "$serverDir\$instanceName\runtime\conf\server.xml" -oldString "8501" -newString $cfInstance.connectorHTTPPort.ToString()
	Edit-StringInFile -filePath "$serverDir\$instanceName\runtime\conf\server.xml" -oldString "8445" -newString $cfInstance.connectorRedirectPort.ToString()
	Edit-StringInFile -filePath "$serverDir\$instanceName\runtime\conf\server.xml" -oldString "cfusion1" -newString $instanceName
	Edit-StringInFile -filePath "$serverDir\$instanceName\runtime\conf\server.xml" -oldString "4001" -newString $cfInstance.receiverPort.ToString()
	Edit-StringInFile -filePath "$serverDir\$instanceName\runtime\conf\server.xml" -oldString "dev_dsn" -newString "$environment_dsn"
}

For ($i = 1; $i -le $instanceCount; $i++) {
	$cfInstance = Add-CFInstanceObj $i
	Edit-CFInstance -cfInstance $cfInstance
}