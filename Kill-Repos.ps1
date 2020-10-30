param ([string]$cliToken = 'OTM3MzUyMDQ1NjE5OtIUggoi4uxXc+QEthuugePmaHIT',
	[string]$project = "DBDemo")
$cli = "C:\atlassian-cli\bitbucket.bat"
$server = "https://eqalm.hq.reotrans.com/bitbucket"

& $cli --server $server --token $cliToken --action getRepositoryList --project $project --file "C:\test.txt"
$csv = Import-Csv -Path C:\test.txt
foreach ($repo in $csv.Name) {
	& $cli --server $server --token $cliToken --action deleteRepository --project $project --repository $repo
}
