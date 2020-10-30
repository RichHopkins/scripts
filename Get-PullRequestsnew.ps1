[string]$cliToken = $env:cliToken
[string]$cliPath = 'D:\atlassian-cli'
[string]$serverRoot = 'https://eqalm.hq.reotrans.com'
[string]$outputFile = "D:\PullRequests.csv"
$cli = "$cliPath\bitbucket.bat"
$server = "$serverRoot/bitbucket"

if (Test-Path $outputFile) {
	Remove-Item $outputFile -Force
}

$projects = (& $cli --server $server --token $cliToken --action getProjectList) -replace "\d{1,2} projects in list", '' | ConvertFrom-Csv
for ($i = 1; $i -le $projects.Count; $i++) {
	$project = $projects[$i - 1]
	$repos = (& $cli --server $server --token $cliToken --action getRepositoryList --project $project.Key) -replace "\d{1,2} repositories in list", '' | ConvertFrom-Csv
	for ($x = 1; $x -le $repos.Count; $x++) {
		$repo = $repos[$x - 1]
		(& $cli --server $server --token $cliToken --action getPullRequestList --project $project.Key --repository $repo.Name --file $outputFile --append) | Out-Null
	}
}

$data = Import-Csv $outputFile
foreach ($user in ($data.Author | Select-Object -Unique)) {
	
}

Send-MailMessage -Attachments $outputFile -To "EQ_Dev.TeamLeads@equator.com", "eq_atl.help@equator.com", "_release.engineer@equator.com" -Subject "Daily Open Pull Request Report" -SmtpServer "smtp-dev" -From "eqDevOps@equator.com"
#Send-MailMessage -Attachments $outputFile -To "richard.hopkins@equator.com" -Subject "Daily Pull Request Report" -SmtpServer "smtp-dev" -From "eqDevOps@equator.com"