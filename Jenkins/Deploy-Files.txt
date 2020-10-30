[CmdletBinding()]
param
(
	[Parameter(Mandatory = $true)]
	[ValidateSet('Development', 'DevInt', 'AlphaX7', 'Alpha', IgnoreCase = $False)]
	[string]$environment
)

Import-Module eqDevOps
. "D:\Workflow\Scripts\Invoke-Parallel.ps1"

$configData = Get-XMLFile "\\DevOps\Config\EQConfig.xml"
$envData = ($configData | Select-Xml -XPath "/Configuration/Environment[@Name=`"$environment`"]").get_node()
$envPath = Join-Path -Path $configData.Configuration.JenkinsData.WorkflowPaths.Environments -ChildPath $environment
$WorkflowPaths = $configData.Configuration.JenkinsData.WorkflowPaths
$isilonPath = $envData.ColdFusion.CFConfig.SourcePath
$cfServers = @()
$cfSitePaths = @{}
foreach ($server in $envData.ColdFusion.Servers.Server) { 
	$cfServers += $server.Name.ToString() 
	$cfSitePaths.Add($server.Name.ToString(), $server.sitePath.ToString())
}
$smServers = @()
$smServersRoles = @{}
foreach ($server in $envData.ServiceMart.Servers.Server) {
	$smServers += $server.Name.ToString()
	$serverRoles = @()
	foreach ($role in $server.Roles.Role) { $serverRoles += $role.Name.ToString() }
	$smServersRoles.Add($server.Name.ToString(), $serverRoles)
}
$Artifacts = $configData.Configuration.Artifacts
$HasingletonArtifacts = @()
foreach ($artifact in $Artifacts.HasingletonArtifacts.Artifact) { $HasingletonArtifacts += $artifact.Name.ToString() }
$cfSMLibFiles = @()
foreach ($artifact in $Artifacts.ServiceMartCFLibFiles.Artifact) { $cfSMLibFiles += $artifact.Name.ToString() }
$binSource = Join-Path -Path $envPath -ChildPath "binaries"
$coreSource = Join-Path -Path $envPath -ChildPath "core"
$smSource = Join-Path -Path $WorkflowPaths.Builds -ChildPath "$environment\Java"

If (Test-Path $binSource) {
	$binPath = $envData.binariesPath.ToString()
	& robocopy `"$binSource`" `"$binPath`" /FX project.pj /E /MT:8 /V
}

& robocopy $coreSource $isilonPath /FX project.pj /E /MT:8 /V

$cfServers | Invoke-Parallel -ImportModules -ImportVariables -ScriptBlock {
	$serverName = $_
	$cfSitePath = $cfSitePaths.Get_Item("$serverName")
	& robocopy $coreSource `"$cfSitePath`" /FX project.pj /E /MT
	& robocopy `"$smSource\DAL\cf`" `"$cfSitePath\ThirdPartyTools\Equator\ServiceMart\DAL`" /FX project.pj /E /MT
	& robocopy `"$smSource`" `"$cfSitePath\ThirdPartyTools\Equator\lib`" $cfSMLibFiles
}

$smServers | Invoke-Parallel -ImportModules -ImportVariables -ScriptBlock {
	$smServer = $_
	$smServerRole = $smServersRoles.Get_Item("$smServer")
	If ($smServerRole -contains "Web") {
		& robocopy `"$smSource`" `"\\$smServer\ServerBox\jboss\soa-p-5.3.1.GA\jboss-as\server\production\deploy`" `"*.*`" /FX project.pj /MT
		& robocopy `"$smSource\5_3`" `"\\$smServer\ServerBox\jboss\soa-p-5.3.1.GA\jboss-as\server\production\deploy`" `"*.*`" /FX project.pj /MT
	}
	If ($smServerRole -contains "UTIL") {
		& robocopy `"$smSource`" `"\\$smServer\ServerBox\jboss\soa-p-5.3.1.GA-UTIL\jboss-as\server\production\deploy`" `"*.*`" /FX project.pj /MT
		& robocopy `"$smSource\5_3_UTIL`" `"\\$smServer\ServerBox\jboss\soa-p-5.3.1.GA-UTIL\jboss-as\server\production\deploy`" `"*.*`" /FX project.pj /MT
		& robocopy `"$smSource\5_3_UTIL`" `"\\$smServer\ServerBox\jboss\soa-p-5.3.1.GA-UTIL\jboss-as\server\production\deploy-hasingelton`" $HasingletonArtifacts
	}
	If ($smServerRole -contains "DAL") {
		& robocopy `"$smSource`" `"\\$smServer\ServerBox\jboss510GA\server\default\deploy`" `"EqDal-6.12.jar`" /FX project.pj /MT
		& robocopy `"$smSource\DAL\jboss`" `"\\$smServer\ServerBox\jboss510GA\server\default\deploy`" `"*.*`" /FX project.pj /MT
	}
}