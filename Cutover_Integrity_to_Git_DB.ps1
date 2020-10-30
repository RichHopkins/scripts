[string]$cliToken = 'OTM3MzUyMDQ1NjE5OtIUggoi4uxXc+QEthuugePmaHIT'
[string]$cliPath = 'C:\atlassian-cli-7.9.0'
[string]$serverRoot = 'https://eqalm.hq.reotrans.com'
[string]$dbPath = "C:\db"

$cli = "$cliPath\bitbucket.bat"
$server = "$serverRoot/bitbucket"
$gitIgnore = @"
project.pj
**/project.pj
"@

#initial pull of Integrity variants
#Start-Process "si.exe" -ArgumentList "createsandbox -R --yes --shared --project=/database/project.pj $dbPath\master"
#Start-Process "si.exe" -ArgumentList "createsandbox -R --yes --shared --project=/database/project.pj --devpath=12.04-Database_Rem_Dev $dbPath\REM"
#Start-Process "si.exe" -ArgumentList "createsandbox -R --yes --shared --project=/database/project.pj --devpath=12.04-Database_Stage $dbPath\Stage"
#Start-Process "si.exe" -ArgumentList "createsandbox -R --yes --shared --project=/database/project.pj --devpath=12.06-Database_Beta $dbPath\Beta"
#Start-Process "si.exe" -ArgumentList "createsandbox -R --yes --shared --project=/database/project.pj --devpath=12.07-Database_Dev_Int $dbPath\DevInt"
#Start-Process "si.exe" -ArgumentList "createsandbox -R --yes --shared --project=/database/project.pj --devpath=12.06-Database_Dev $dbPath\Dev"

#resync Integrity variants if needed
$dirs = Get-ChildItem -Path $dbPath -Directory
foreach ($dir in $dirs.FullName) {
	Start-Process "si.exe" -ArgumentList "resync --sandbox=$dir\project.pj" -Wait
}

$dirs = Get-ChildItem -Path $dbPath -Directory
foreach ($dir in $dirs) {
	$dirPath = $dir.FullName
	Get-ChildItem -Path $dirPath -Exclude project.pj | Remove-Item -Force
	Get-ChildItem -Path "$dirPath/OLTP/reotrans/scripts" -Exclude project.pj | Where-Object {
		$_.LastWriteTime -lt (Get-Date -Date 1/1/2019)
	} | Remove-Item -Force
	foreach ($delDir in Get-Content "C:\DBList.txt") {
		Remove-Item $dirPath\$delDir -Recurse -Force -ErrorAction SilentlyContinue
	}
}

$dirs = Get-ChildItem -Path "$dbPath\master" -Directory
foreach ($dir in $dirs) {
	$repo = $dir.Name
	$repoPath = $dir.FullName
	
	#Setup master
	Set-Location $repoPath
	& $cli --server $server --token $cliToken --action createRepository --project "DB" --repository $repo
	Set-Content -Value $gitIgnore -Path $repoPath\.gitignore -Encoding Ascii -Force
	git init
	git add --all
	git commit -m "Initial Commit"
	git remote add origin https://eqalm.hq.reotrans.com/bitbucket/scm/db/$repo.git
	git push -u origin master
	git pull
	
	#Setup REM
	$commit = git rev-list --simplify-by-decoration -1 HEAD
	& $cli --server $server --token $cliToken --action addBranch --project "DB" --repository $repo --branch "release/12.04.21" --id $commit
	git pull
	git checkout release/12.04.21
	git pull origin release/12.04.21
	Move-Item -Path .\.git -Destination $dbPath\.git -Force
	Robocopy $dbPath\REM\$repo $repoPath /mir /mt
	Set-Content -Value $gitIgnore -Path $repoPath\.gitignore -Encoding Ascii -Force
	Move-Item -Path $dbPath\.git -Destination .\.git -Force
	git add *
	git commit -m "Initial Commit of REM to release/12.04.21"
	git push origin release/12.04.21
	git pull origin release/12.04.21
	
	#Setup Stage
	$commit = git rev-list --simplify-by-decoration -1 HEAD
	& $cli --server $server --token $cliToken --action addBranch --project "DB" --repository $repo --branch "release/12.04" --id $commit
	git pull
	git checkout release/12.04
	git pull origin release/12.04
	Move-Item -Path .\.git -Destination $dbPath\.git -Force
	Robocopy $dbPath\Stage\$repo $repoPath /mir /mt
	Set-Content -Value $gitIgnore -Path $repoPath\.gitignore -Encoding Ascii -Force
	Move-Item -Path $dbPath\.git -Destination .\.git -Force
	git add *
	git commit -m "Initial Commit of Stage to release/12.04"
	git push origin release/12.04
	git pull origin release/12.04
	
	#Setup Beta
	& $cli --server $server --token $cliToken --action addBranch --project "DB" --repository $repo --branch "release/12.06" --id $commit
	git pull
	git checkout release/12.06
	git pull origin release/12.06
	Move-Item -Path .\.git -Destination $dbPath\.git -Force
	Robocopy $dbPath\Beta\$repo $repoPath /mir /mt
	Set-Content -Value $gitIgnore -Path $repoPath\.gitignore -Encoding Ascii -Force
	Move-Item -Path $dbPath\.git -Destination .\.git -Force
	git add *
	git commit -m "Initial Commit of Beta to release/12.06"
	git push origin release/12.06
	git pull origin release/12.06
	
	#Setup DevInt
	& $cli --server $server --token $cliToken --action addBranch --project "DB" --repository $repo --branch "release/12.07" --id $commit
	git pull
	git checkout release/12.07
	git pull origin release/12.07
	Move-Item -Path .\.git -Destination $dbPath\.git -Force
	Robocopy $dbPath\DevInt\$repo $repoPath /mir /mtmt
	Set-Content -Value $gitIgnore -Path $repoPath\.gitignore -Encoding Ascii -Force
	Move-Item -Path $dbPath\.git -Destination .\.git -Force
	git add *
	git commit -m "Initial Commit of DevInt to release/12.07"
	git push origin release/12.07
	git pull origin release/12.07
	
	#Setup Dev
	& $cli --server $server --token $cliToken --action addBranch --project "DB" --repository $repo --branch "Development" --id $commit
	git pull
	git checkout Development
	git pull origin Development
	Move-Item -Path .\.git -Destination $dbPath\.git -Force
	Robocopy $dbPath\Dev\$repo $repoPath /mir /mt
	Set-Content -Value $gitIgnore -Path $repoPath\.gitignore -Encoding Ascii -Force
	Move-Item -Path $dbPath\.git -Destination .\.git -Force
	git add *
	git commit -m "Initial Commit of Dev Development to Development"
	git push origin Development
	git pull origin Development
}
