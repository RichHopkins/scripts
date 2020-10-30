[CmdletBinding()]
param
(
	[Parameter(Mandatory = $true)]
	[ValidateSet('Development', 'DevInt', 'AlphaX7', 'Alpha', IgnoreCase = $False)]
	[string]$environment
)

Import-Module eqDevOps

$configData = Get-XMLFile "\\DevOps\Config\EQConfig.xml"
$envPath = Join-Path -Path $configData.Configuration.JenkinsData.WorkflowPaths.Builds -ChildPath $environment
$thisBuildFile = "$envPath\thisBuildTime.txt"
foreach ($i in Get-Content $thisBuildFile) {
	$script:dtThisBuild = $i
}
Remove-Item -Path "$envPath\lastBuildTime.txt" -Force
New-Item -Path "$envPath\lastBuildTime.txt" -ItemType file -Value $dtThisBuild