[string]$cliToken = 'OTM3MzUyMDQ1NjE5OtIUggoi4uxXc+QEthuugePmaHIT'
[string]$cliPath = 'C:\atlassian-cli-7.9.0'
[string]$serverRoot = 'https://eqalm.hq.reotrans.com'
[string]$binPath = "C:\binaries"

$cli = "$cliPath\bitbucket.bat"
$server = "$serverRoot/bitbucket"

#prep Integrity variants
# Start-Process "si.exe" -ArgumentList "createsandbox -R --yes --shared --project=/binaries/project.pj $smPath\mainline"
# Start-Process "si.exe" -ArgumentList "createsandbox -R --yes --shared --project=/binaries/project.pj --devpath=12.02-binaries_Rem_Dev $smPath\REM"
# Start-Process "si.exe" -ArgumentList "createsandbox -R --yes --shared --project=/binaries/project.pj --devpath=12.03-binaries_Beta $smPath\Beta"
# Start-Process "si.exe" -ArgumentList "createsandbox -R --yes --shared --project=/binaries/project.pj --devpath=12.04-binaries_Dev_Int $smPath\DevInt"
# Start-Process "si.exe" -ArgumentList "createsandbox -R --yes --shared --project=/binaries/project.pj --devpath=12.03-binaries_Dev $smPath\Dev"

#resync Integrity variants
$dirs = Get-ChildItem -Path "C:\binaries" -Directory
foreach ($dir in $dirs.FullName) {
	Start-Process "si.exe" -ArgumentList "resync --sandbox=$dir\project.pj"
}

Robocopy C:\binaries C:\binaries2 /mir /mt
Set-Location C:\binaries
Invoke-Expression -Command "C:\scripts\Find-StringinDirs.ps1 -path 'C:\binaries' -log 'C:\binary_finds.txt' -testFile 'Z:\Sintayow\Rich\BinariesLenderList.txt'"
Get-ChildItem -Path C:\binaries -Filter project.pj -Recurse -Force | Remove-Item -Force
$delDirs = @(Get-Content -Path C:\binary_finds.txt)
foreach ($dir in $delDirs) {Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue}

#Setup mainline
Set-Location "C:\binaries\mainline"
git init
git add --all
git commit -m "Initial Commit"
git remote add origin https://eqalm.hq.reotrans.com/bitbucket/scm/core/binaries.git
git push -u origin master
git pull

#Setup REM
$commit = git rev-list --simplify-by-decoration -1 HEAD
& $cli --server $server --token $cliToken --action addBranch --project "CORE" --repository 'binaries' --branch "release/12.04.21" --id $commit
git pull
git checkout release/12.04.21
git pull origin release/12.04.21
Move-Item -Path .\.git -Destination C:\binaries\.git -Force
Robocopy C:\binaries\REM C:\binaries\mainline /mir /mt
Get-ChildItem -Filter *.pj -Force -Recurse | Remove-Item -Force
Move-Item -Path C:\binaries\.git -Destination .\.git -Force
git add *
git commit -m "Initial Commit of REM to release/12.04.21"
git push origin release/12.04.21
git pull origin release/12.04.21

#Setup Stage
$commit = git rev-list --simplify-by-decoration -1 HEAD
& $cli --server $server --token $cliToken --action addBranch --project "CORE" --repository 'binaries' --branch "release/12.04" --id $commit
git pull
git checkout release/12.04
git pull origin release/12.04
Move-Item -Path .\.git -Destination C:\binaries\.git -Force
Robocopy C:\binaries\Stage C:\binaries\mainline /mir /mt
Get-ChildItem -Filter *.pj -Force -Recurse | Remove-Item -Force
Move-Item -Path C:\binaries\.git -Destination .\.git -Force
git add *
git commit -m "Initial Commit of Stage to release/12.04"
git push origin release/12.04
git pull origin release/12.04

#Setup Beta
& $cli --server $server --token $cliToken --action addBranch --project "CORE" --repository 'binaries' --branch "release/12.06" --id $commit
git pull
git checkout release/12.06
git pull origin release/12.06
Move-Item -Path .\.git -Destination C:\binaries\.git -Force
Robocopy C:\binaries\Beta C:\binaries\mainline /mir /mt
Get-ChildItem -Filter *.pj -Force -Recurse | Remove-Item -Force
Move-Item -Path C:\binaries\.git -Destination .\.git -Force
git add *
git commit -m "Initial Commit of Beta to release/12.06"
git push origin release/12.06
git pull origin release/12.06

#Setup DevInt
& $cli --server $server --token $cliToken --action addBranch --project "CORE" --repository 'binaries' --branch "release/12.07" --id $commit
git pull
git checkout release/12.07
git pull origin release/12.07
Move-Item -Path .\.git -Destination C:\binaries\.git -Force
Robocopy C:\binaries\DevInt C:\binaries\mainline /mir /mt
Get-ChildItem -Filter *.pj -Force -Recurse | Remove-Item -Force
Move-Item -Path C:\binaries\.git -Destination .\.git -Force
git add *
git commit -m "Initial Commit of DevInt to release/12.07"
git push origin release/12.07
git pull origin release/12.07

#Setup Dev
& $cli --server $server --token $cliToken --action addBranch --project "CORE" --repository 'binaries' --branch "Development" --id $commit
git pull
git checkout Development
git pull origin Development
Move-Item -Path .\.git -Destination C:\binaries\.git -Force
Robocopy C:\binaries\Dev C:\binaries\mainline /mir /mt
Get-ChildItem -Filter *.pj -Force -Recurse | Remove-Item -Force
Move-Item -Path C:\binaries\.git -Destination .\.git -Force
git add *
git commit -m "Initial Commit of Dev to Development"
git push origin Development
git pull origin Development
