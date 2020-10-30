param (
	[string]$cliToken = 'OTM3MzUyMDQ1NjE5OtIUggoi4uxXc+QEthuugePmaHIT',
	[string]$cliPath = 'C:\atlassian-cli',
	[string]$serverRoot = 'https://eqalm.hq.reotrans.com',
	[string]$rootDir = "C:\AllGitRepos"
)
$cli = "$cliPath\bitbucket.bat"
$server = "$serverRoot/bitbucket"
Set-Location $rootDir

$projects = (& $cli --server $server --token $cliToken --action getProjectList) -replace "\d{1,2} projects in list", '' | ConvertFrom-Csv
for ($i = 1; $i -le $projects.Count; $i++) {
	$project = $projects[$i - 1]
	$projectKey = $project.Key
	New-Item -Path "$rootDir\$projectKey" -ItemType directory -Force | Out-Null
	$repos = (& $cli --server $server --token $cliToken --action getRepositoryList --project $projectKey) -replace "\d{1,2} repositories in list", '' | ConvertFrom-Csv
	Push-Location "$rootDir\$projectKey"
	for ($x = 1; $x -le $repos.Count; $x++) {
		$repo = $repos[$x - 1]
		$cloneUrl = $repo.'Clone URL'
		git clone $cloneUrl
	}
	Pop-Location
}