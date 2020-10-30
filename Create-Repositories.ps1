param ([string]$cliToken = 'Your Token Here')
Set-Location "C:\atlassian-cli-7.9.0"
$dirs = Get-ChildItem -Path "C:\ServiceMart\ng\projects"
foreach ($dir in $dirs) {
	$repo = $dir.Name
	.\bitbucket.bat --server https://eqalm.hq.reotrans.com/bitbucket --token $cliToken --action createRepository --project "SM" --repository $repo --name $repo --public
	Push-Location -Path $dir.FullName
	git init
	git add --all
	git commit -m "Initial Commit"
	git remote add origin https://richard.hopkins@eqalm.hq.reotrans.com/bitbucket/scm/test/$repo.git
	git push -u origin master
	Pop-Location
}
