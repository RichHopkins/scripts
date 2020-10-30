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
$envPath = (Join-Path -Path $JenkinsData.WorkflowPaths.Environments -ChildPath $environment)
$buildPath = (Join-Path -Path $JenkinsData.WorkflowPaths.Builds -ChildPath "$environment\Java")
$logPath = (Join-Path -Path $JenkinsData.WorkflowPaths.Builds -ChildPath "$environment\Logs\Java")
$smProjectPath = (Join-Path -Path $envPath -ChildPath "servicemart")

$ParentInstallPOMs = $configData.Configuration.ServiceMartPOMs.ParentInstallPOMs.SelectNodes("*")
For ($i = 0; $i -lt $ParentInstallPOMs.Count; $i++) {
	$pomPath = (Join-Path -Path $smProjectPath -ChildPath "$($ParentInstallPOMs[$i].Name)\pom.xml")
	Invoke-Maven -goal clean -pomPath $pomPath
	Invoke-Maven -goal install -pomPath $pomPath | Tee-Object -filepath "$logPath\$($ParentInstallPOMs[$i].Name)_install.log"
}

$ParentDeployPOMs = $configData.Configuration.ServiceMartPOMs.ParentDeployPOMs.SelectNodes("*")
For ($i = 0; $i -lt $ParentDeployPOMs.Count; $i++) {
	$pomPath = (Join-Path -Path $smProjectPath -ChildPath "$($ParentDeployPOMs[$i].Name)\pom.xml")
	Invoke-Maven -goal clean -pomPath $pomPath
	Invoke-Maven -goal deploy -pomPath $pomPath -deployPath $buildPath | Tee-Object -filepath "$logPath\$($ParentDeployPOMs[$i].Name)_deploy.log"
}

Remove-Item -Path "$envPath\lastBuildTime.txt" -Force
New-Item -Path "$envPath\lastBuildTime.txt" -ItemType file -Value (Get-Date -format "MMM d, yyyy hh:00:00 tt")