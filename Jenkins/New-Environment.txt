[CmdletBinding()]
param
(
	[Parameter(Mandatory = $true)]
	[ValidateSet('Development', 'DevInt', 'AlphaX7', 'Alpha', IgnoreCase = $False)]
	[string]$environment
)

Import-Module eqDevOps

$configData = Get-XMLFile "\\DevOps\Config\EQConfig.xml"
$JenkinsData = $configData.Configuration.JenkinsData
$IntegrityUser = $JenkinsData.IntegrityData.IntegrityUser
$IntegrityPass = $JenkinsData.IntegrityData.IntegrityPass
$envPath = (Join-Path -Path $JenkinsData.WorkflowPaths.Environments -ChildPath $environment)
$envData = ($configData | Select-Xml -XPath "/Configuration/Environment[@Name=`"$environment`"]").get_node()

Connect-Integrity -username $IntegrityUser -password $IntegrityPass

$Variants = $envData.BuildData.Variants.SelectNodes("*")
For ($i = 0; $i -lt $Variants.Count; $i++)
{
	Write-Output "Creating sandbox for project $($Variants[$i].Project.ToString()) - variant $($Variants[$i].Name.ToString())"
	New-IntegritySandbox -project "$($Variants[$i].Project.ToString())" -variant "$($Variants[$i].Name.ToString())" -path (Join-Path -Path $envPath -ChildPath "$($Variants[$i].Project.ToString())") -username $IntegrityUser -password $IntegrityPass
}

Disconnect-Integrity -username $IntegrityUser -password $IntegrityPass
Exit-Integrity