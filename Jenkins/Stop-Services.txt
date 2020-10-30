[CmdletBinding()]
param
(
	[Parameter(Mandatory = $true)]
	[ValidateSet('Development', 'DevInt', 'AlphaX7', 'Alpha', IgnoreCase = $False)]
	[string]$environment,
	[bool]$CFOnly = $False
)

Import-Module eqDevOps
. "D:\Workflow\Scripts\Invoke-Parallel.ps1"

$configData = Get-XMLFile "\\DevOps\Config\EQConfig.xml"
$envData = ($configData | Select-Xml -XPath "/Configuration/Environment[@Name=`"$environment`"]").get_node()

$cfServers = @()
foreach ($server in $envData.ColdFusion.Servers.Server) { $cfServers += $server.Name.ToString() }
$smServers = @()
foreach ($server in $envData.ServiceMart.Servers.Server) { $smServers += $server.Name.ToString() }

$cfServers | Invoke-Parallel -ImportVariables -ImportModules -ScriptBlock {
	$server = "$_"
	$cfServices = (Get-WmiObject -Query "SELECT * FROM Win32_Service WHERE Name LIKE 'Adobe CF%'" -ComputerName $server -Verbose)
	ForEach ($cfService in $cfServices) {
		Stop-RemoteService -serverName $server -serviceName $cfService.Name
	}
}


if ($CFOnly -eq $False) {
	$smServers | Invoke-Parallel -ImportVariables -ImportModules -ScriptBlock {
		$server = "$_"
		$smServices = (Get-WmiObject -Query "SELECT * FROM Win32_Service WHERE Name LIKE 'JB%'" -ComputerName $server)
		if (!$smServices) { Write-Output "No services found." }
		ForEach ($smService in $smServices) {
			Stop-RemoteService -serverName $server -serviceName $smService.Name
		}
	}
}