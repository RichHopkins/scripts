[CmdletBinding()]
param
(
	[Parameter(Mandatory = $true)]
	[ValidateSet('DevInt', 'AlphaX7', IgnoreCase = $False)]
	[string]$environment
)

Import-Module eqDevOps

$configData = Get-XMLFile "\\DevOps\Config\EQConfig.xml"
$JenkinsData = $configData.Configuration.JenkinsData
$IntegrityUser = $JenkinsData.IntegrityData.IntegrityUser
$IntegrityPass = $JenkinsData.IntegrityData.IntegrityPass
$envPath = Join-Path -Path $JenkinsData.WorkflowPaths.Environments -ChildPath $environment
$envData = ($configData | Select-Xml -XPath "/Configuration/Environment[@Name=`"$environment`"]").get_node()

Connect-Integrity -username $IntegrityUser -password $IntegrityPass

$Variants = $envData.BuildData.Variants.SelectNodes("*")
For ($i = 0; $i -lt $Variants.Count; $i++)
{
	Write-Output "Resyncing $environment sandbox at $(Join-Path -Path $envPath -ChildPath "$($Variants[$i].Project.ToString())")"
	Sync-IntegritySandbox -Path (Join-Path -Path $envPath -ChildPath "$($Variants[$i].Project.ToString())") -username $IntegrityUser -password $IntegrityPass
}

Write-Output "Completed downloading $environment from Integrity at: $(Get-Date -Format g)"
Disconnect-Integrity -username $IntegrityUser -password $IntegrityPass
Exit-Integrity

Write-Output "Resync $environment completed at: $(Get-Date -Format g)"