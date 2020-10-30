param (
	[string]$cliToken = 'OTM3MzUyMDQ1NjE5OtIUggoi4uxXc+QEthuugePmaHIT',
	[string]$cliPath = 'C:\atlassian-cli',
	[string]$serverRoot = 'https://eqalm.hq.reotrans.com',
	[string]$outputFile = "C:\commits.csv"
)
$cli = "$cliPath\bitbucket.bat"
$server = "$serverRoot/bitbucket"
$yesterday = (Get-Date).AddDays(-14)
$startDate = Get-Date -Date $yesterday -Format yyyy-MM-dd

if (Test-Path $outputFile) {
	Remove-Item $outputFile -Force
}

$projects = (& $cli --server $server --token $cliToken --action getProjectList) -replace "\d{1,2} projects in list", '' | ConvertFrom-Csv
for ($i = 1; $i -le $projects.Count; $i++) {
	$project = $projects[$i - 1]
	$repos = (& $cli --server $server --token $cliToken --action getRepositoryList --project $project.Key) -replace "\d{1,2} repositories in list", '' | ConvertFrom-Csv
	for ($x = 1; $x -le $repos.Count; $x++) {
		$repo = $repos[$x - 1]
		(& $cli --server $server --token $cliToken --action getCommitList --project $project.Key --repository $repo.Name --file $outputFile --append --startDate $startDate) | Out-Null
	}
}
#Send-MailMessage -Attachments $outputFile -To "EQ_Dev.TeamLeads@equator.com", "eq_atl.help@equator.com", "_release.engineer@equator.com" -Subject "Daily 24 Hour Commit Report" -SmtpServer "smtp-dev" -From "eqDevOps@equator.com"