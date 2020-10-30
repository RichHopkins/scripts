[CmdletBinding()]
param
(
	[Parameter(Mandatory = $true)]
	[ValidateSet('Alpha', IgnoreCase = $true)]
	[string]$environment
)

Import-Module eqDevOps
. "D:\Workflow\Scripts\Invoke-Parallel.ps1"

$configData = Get-XMLFile "\\DevOps\Config\EQConfig.xml"
$JenkinsData = $configData.Configuration.JenkinsData
$envPath = (Join-Path -Path $JenkinsData.WorkflowPaths.Builds -ChildPath $environment)
$IntegrityUser = $JenkinsData.IntegrityData.IntegrityUser
$IntegrityPass = $JenkinsData.IntegrityData.IntegrityPass

Connect-Integrity -username $IntegrityUser -password $IntegrityPass

foreach ($i in Get-Content "$envPath\thisDeployTime.txt") {
    $script:dtThisDeploy = $i
}

$fState = '"Active","Submit"'
$qD = "((field[Environment] = Alpha) and (field[Type] = Deploy Task) and (field[State] = $fState) and (field[Modified Date] between time Jan 1, 2013 12:00:00 AM and $dtThisDeploy))"
im.exe editquery --yes --user=$IntegrityUser --password=$IntegrityPass --queryDefinition="$qD" "Automation Alpha Deploy Tasks"

$DeployTasks = im.exe issues --user=$IntegrityUser --password=$IntegrityPass --query='Automation Alpha Deploy Tasks' --fields=ID
$assignUserValue = "Assigned User=svc-mks.jenkins"
$activeValue = "State=Active"
$completeValue = "State=Complete"
foreach ($id in $DeployTasks) {
	write-host $id
	im.exe editissue --field=$assignUserValue $id
	im.exe editissue --field=$activeValue $id
	im.exe editissue --field=$completeValue $id
}

$FlipDeployIssues = im.exe issues --user=$IntegrityUser --password=$IntegrityPass --query='Automation Alpha Issues Ready to Deploy' --fields=ID
$completeDeployValue = "State=Deployed"
foreach ($id in $FlipDeployIssues) {
	im.exe editissue --field=$completeDeployValue $id
}

$FlipIssues = im.exe issues --user=$IntegrityUser --password=$IntegrityPass --query='Automation Alpha Issues Deployed' --fields=ID
$completeValue = "State=Ready to Test"
foreach ($id in $FlipIssues) {
	im.exe editissue --field=$completeValue $id
}

Disconnect-Integrity -username $IntegrityUser -password $IntegrityPass
Exit-Integrity