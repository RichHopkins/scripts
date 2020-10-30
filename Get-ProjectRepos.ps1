param ([string]$cliToken,
    [string]$projectName)

Set-Location "C:\atlassian-cli-7.9.0"
$file = "C:\repos.csv"
.\bitbucket.bat --server https://eqalm.hq.reotrans.com/bitbucket --token $cliToken --action getRepositoryList --project $projectName | Out-File $file
Get-Content $file | Select-Object -Skip 1 | Set-Content "$file-temp"
Move-Item "$file-temp" $file -Force

If (-not(Test-Path "C:\git\$projectName")) {
	New-Item -Path "C:\git\$projectName" -ItemType Directory
}
Set-Location "C:\git\$projectName"
$repos = Import-Csv $file
ForEach ($repo in $repos) {
	$cloneUrl = $repo.'Clone URL'
	git clone $cloneUrl
}
