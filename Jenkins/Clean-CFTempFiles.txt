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
$cfServers = @()
foreach ($server in $envData.ColdFusion.Servers.Server) { $cfServers += $server.Name.ToString() }

$cfServers | Invoke-Parallel -ImportModules -ImportVariables -ScriptBlock {
	$server = $_
	$cfDirs = Get-ChildItem "\\$server\ServerBox\Servers\JRun4\servers" -Directory -Filter "cfusion9*"
	foreach ($cfDir in $cfDirs) {
		Write-Output "Removing $($cfDir.FullName)\SERVER-INF\temp\cfusion.war-tmp\*"
		Remove-Item "$($cfDir.FullName)\SERVER-INF\temp\cfusion.war-tmp\*" -force
		$JINIClusterLogs = Get-ChildItem "$($cfDir.FullName)\SERVER-INF\temp\" -filter "JINIClusterLog*" | Where-Object { $_.PSIsContainer -and $_.LastWriteTime -le [System.DateTime]::Now.AddDays(-1) }
		foreach ($JINIClusterLog in $JINIClusterLogs) {
			Write-Output "Removing $($JINIClusterLog.FullName)"
			Remove-Item $JINIClusterLog.FullName -Recurse -Force
		}
	}
}