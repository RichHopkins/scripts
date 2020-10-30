param (
	[string]$cliToken = 'your token here',
	[string]$cliPath = 'C:\atlassian-cli-7.9.0',
	[string]$serverRoot = 'https://eqalm.hq.reotrans.com',
	[string]$outputFile = "C:\BranchList.csv"
)
$cli = "$cliPath\bitbucket.bat"
$server = "$serverRoot/bitbucket"
Import-Module eqDevOps
Set-Location $cliPath
if (Test-Path $outputFile) {Remove-Item $outputFile -Force}

$projects = (& $cli --server $server --token $cliToken --action getProjectList) -replace "\d{1,2} projects in list", '' | ConvertFrom-Csv
for ($i = 1; $i -le $projects.Count; $i++) {
	$project = $projects[$i - 1]
	Write-Progress -Activity 'Searching all Projects' -Status "Searching through $($project.Name)" -PercentComplete (($i/$projects.Count) * 100) -Id 1
	$repos = (& $cli --server $server --token $cliToken --action getRepositoryList --project $project.Key) -replace "\d{1,2} repositories in list", '' | ConvertFrom-Csv
	for ($x = 1; $x -le $repos.Count; $x++) {
		$repo = $repos[$x - 1]
		Write-Progress -Activity "Searching all Repos in $($project.Name)" -Status "Searching through $($repo.Name)" -PercentComplete (($x/$repos.Count) * 100) -ParentId 1
		$branches = (& $cli --server $server --token $cliToken --action getBranchList --project $project.Key --repository $repo.Name --file $outputFile --append) -replace "\d{1,2} branches in list .*", '' | ConvertFrom-Csv
		if ($x -eq $repos.Count) {
			Write-Progress -Activity "Searching all Repos in $($project.Name)" -Status "Searching through $($repo.Name)" -PercentComplete (($x/$repos.Count) * 100) -ParentId 1 -Completed
		}
	}
	if ($i -eq $projects.Count) {
		Write-Progress -Activity 'Searching all Projects' -Status "Searching through $($project.Name)" -PercentComplete (($i/$projects.Count) * 100) -Id 1 -Completed
	}
}

(Get-Content $outputFile) -notmatch "refs/heads/master" `
	-notmatch "refs/heads/Development" `
	-notmatch "refs/heads/releas*" `
	-notmatch "refs/heads/Architecture" `
	-notmatch "refs/heads/Custom" `
	-notmatch "refs/heads/Global" | `
	Set-Content $outputFile
Import-Csv $outputFile | Select-Object *, "Latest Commit Date", "Latest Commit Author" | Export-Csv "$outputFile.tmp" -NoTypeInformation
$import = (Import-Csv "$outputFile.tmp")
for ($i = 1; $i -le $import.Count; $i++) {
	$row = $import[$i - 1]
	Write-Progress -Activity 'Searching all Commits' -Status "Fetching $($row.'Latest Commit') from $($row.Project) - $($row.Repository)" -PercentComplete (($i/$import.Count) * 100)
	$commitData = & $cli --server $server --token $cliToken --action getCommit --project $row.Project --repository $row.Repository --id $row.'Latest Commit'
	$author = $commitData -match 'Author  . . . . . . . . . . . : .*'
	$author = $author -replace 'Author  . . . . . . . . . . . : ', ''
	$date = $commitData -match 'Commit date . . . . . . . . . : .*'
	$date = $date -replace 'Commit date . . . . . . . . . : ', ''
	$row.'Latest Commit Author' = $author
	$row.'Latest Commit Date' = $date
	$row.'Latest Commit Author' = $row.'Latest Commit Author'.ToLower()
	$row.'Latest Commit Date' = $row.'Latest Commit Date'.ToLower()
}
$import | Export-Csv -Path $outputFile -Force -NoTypeInformation
Remove-Item "$outputFile.tmp" -Force
Send-MailMessage -Attachments $outputFile -To "EQ_Dev.TeamLeads@equator.com; eq_atl.help@equator.com; _release.engineer@equator.com" -Subject "Daily Branch List Report" -SmtpServer "smtp-dev"