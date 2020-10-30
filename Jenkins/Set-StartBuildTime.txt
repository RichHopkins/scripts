[CmdletBinding()]
param
(
	[Parameter(Mandatory = $true)]
	[ValidateSet('Development', 'DevInt', 'AlphaX7', 'Alpha', IgnoreCase = $False)]
	[string]$environment
)

Import-Module eqDevOps

$configData = Get-XMLFile "\\DevOps\Config\EQConfig.xml"
$envPath = Join-Path -Path $configData.Configuration.JenkinsData.WorkflowPaths.Builds-ChildPath $environment
Remove-Item -Path "$envPath\thisBuildTime.txt" -Force
New-Item -Path "$envPath\thisBuildTime.txt" -ItemType file -Value (Get-Date -format "MMM d, yyyy hh:00:00 tt")