$userName = "svc-mks.jenkins"
$apiToken = "115b1c5a3871a02fa7d230a04b299896ff"
$server = "jenkins.hq.reotrans.com"
$jobToken = "Password1"

$jobNames = @(
	"DevInt%20-%20SMBuild%20SOA%20-%20Git",
	"DevInt%20-%20SMBuild%20ServicemartFuseParent",
	"DevInt%20-%20SMBuild%20ServicemartFeatures",
	"DevInt%20-%20SMBuild%20Archetypes",
	"DevInt%20-%20SMBuild%20EQDAL",
	"DevInt%20-%20SMBuild%20VI",
	"DevInt%20-%20SMBuild%20Idology",
	"DevInt%20-%20SMBuild%20Common%20-%20Git",
	"DevInt%20-%20SMBuild%20CFPB",
	"DevInt%20-%20SMBuild%20EventHandler%20-%20Git",
	"DevInt%20-%20SMBuild%20Schedulers%20-%20Git",
	"DevInt%20-%20SMBuild%20SMUtilities",
	"DevInt%20-%20SMBuild%20SMLoggerService",
	"DevInt%20-%20SMBuild%20Agent%20-%20Git",
	"DevInt%20-%20SMBuild%20Utils",
	"DevInt%20-%20SMBuild%20Expense",
	"DevInt%20-%20SMBuild%20PropertyImport",
	"DevInt%20-%20SMBuild%20ASPS"
)

foreach ($jobName in $jobNames) {
	$params = @{
		uri = "https://$server/job/$jobName/polling?token=$jobToken"
		Method = "Get"
		Headers = @{
			Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($userName):$($apiToken)"))
		}
	}
	$jobName
	Write-Output "Polling $jobName"
	Invoke-Restmethod @params | Out-Null
}