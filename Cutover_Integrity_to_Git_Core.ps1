[string]$cliToken = 'OTM3MzUyMDQ1NjE5OtIUggoi4uxXc+QEthuugePmaHIT'
[string]$cliPath = 'C:\atlassian-cli-7.9.0'
[string]$serverRoot = 'https://eqalm.hq.reotrans.com'
[string]$binPath = "C:\core"

$cli = "$cliPath\bitbucket.bat"
$server = "$serverRoot/bitbucket"

#prep Integrity variants
# Start-Process "si.exe" -ArgumentList "createsandbox -R --yes --shared --project=/core/project.pj $smPath\mainline"
# Start-Process "si.exe" -ArgumentList "createsandbox -R --yes --shared --project=/core/project.pj --devpath=12.02-core_Rem_Dev $smPath\REM"
# Start-Process "si.exe" -ArgumentList "createsandbox -R --yes --shared --project=/core/project.pj --devpath=12.03-core_Beta $smPath\Beta"
# Start-Process "si.exe" -ArgumentList "createsandbox -R --yes --shared --project=/core/project.pj --devpath=12.04-core_Dev_Int $smPath\DevInt"
# Start-Process "si.exe" -ArgumentList "createsandbox -R --yes --shared --project=/core/project.pj --devpath=12.03-core_Dev $smPath\Dev"

#resync Integrity variants
$dirs = Get-ChildItem -Path "C:\core" -Directory
foreach ($dir in $dirs.FullName) {
	Start-Process "si.exe" -ArgumentList "resync --sandbox=$dir\project.pj"
}

Robocopy C:\core C:\core2 /mir /mt
Invoke-Expression -Command "C:\Find-StringinDirs.ps1 -path 'C:\core' -log 'C:\core_finds.txt' -testFile 'Z:\Sintayow\Rich\BinariesLenderList.txt'"
Get-ChildItem -Path C:\core -Filter project.pj -Recurse -Force | Remove-Item -Force
$delDirs = @(Get-Content -Path C:\core_finds.txt)
foreach ($dir in $delDirs) {Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue}

#Setup mainline
Set-Location "C:\core\mainline"
git init
git add --all
git commit -m "Initial Commit"
git remote add origin https://eqalm.hq.reotrans.com/bitbucket/scm/core/v5.git
git push -u origin master
git pull

#Setup REM
$commit = git rev-list --simplify-by-decoration -1 HEAD
& $cli --server $server --token $cliToken --action addBranch --project "CORE" --repository 'v5' --branch "release/12.04.21" --id $commit
git pull
git checkout release/12.04.21
git pull origin release/12.04.21
Move-Item -Path .\.git -Destination C:\core\.git -Force
Robocopy C:\core\REM C:\core\mainline /mir /mt
Get-ChildItem -Filter *.pj -Force -Recurse | Remove-Item -Force
Move-Item -Path C:\core\.git -Destination .\.git -Force
git add *
git commit -m "Initial Commit of REM to release/12.04.21"
git push origin release/12.04.21
git pull origin release/12.04.21

#Setup Stage
$commit = git rev-list --simplify-by-decoration -1 HEAD
& $cli --server $server --token $cliToken --action addBranch --project "CORE" --repository 'v5' --branch "release/12.04" --id $commit
git pull
git checkout release/12.04
git pull origin release/12.04
Move-Item -Path .\.git -Destination C:\core\.git -Force
Robocopy C:\core\Stage C:\core\mainline /mir /mt
Get-ChildItem -Filter *.pj -Force -Recurse | Remove-Item -Force
Move-Item -Path C:\core\.git -Destination .\.git -Force
git add *
git commit -m "Initial Commit of Stage to release/12.04"
git push origin release/12.04
git pull origin release/12.04

#Setup Beta
& $cli --server $server --token $cliToken --action addBranch --project "CORE" --repository 'v5' --branch "release/12.06" --id $commit
git pull
git checkout release/12.06
git pull origin release/12.06
Move-Item -Path .\.git -Destination C:\core\.git -Force
Robocopy C:\core\Beta C:\core\mainline /mir /mt
Get-ChildItem -Filter *.pj -Force -Recurse | Remove-Item -Force
Move-Item -Path C:\core\.git -Destination .\.git -Force
git add *
git commit -m "Initial Commit of Beta to release/12.06"
git push origin release/12.06
git pull origin release/12.06

#Setup DevInt
& $cli --server $server --token $cliToken --action addBranch --project "CORE" --repository 'v5' --branch "release/12.07" --id $commit
git pull
git checkout release/12.07
git pull origin release/12.07
Move-Item -Path .\.git -Destination C:\core\.git -Force
Robocopy C:\core\DevInt C:\core\mainline /mir /mt
Get-ChildItem -Filter *.pj -Force -Recurse | Remove-Item -Force
Move-Item -Path C:\core\.git -Destination .\.git -Force
git add *
git commit -m "Initial Commit of DevInt to release/12.07"
git push origin release/12.07
git pull origin release/12.07

#Setup Global
& $cli --server $server --token $cliToken --action addBranch --project "CORE" --repository 'v5' --branch "Global" --id $commit
git pull
git checkout Global
git pull origin Global
Move-Item -Path .\.git -Destination C:\core\.git -Force
Robocopy C:\core\Global C:\core\mainline /mir /mt
Get-ChildItem -Filter *.pj -Force -Recurse | Remove-Item -Force
Move-Item -Path C:\core\.git -Destination .\.git -Force
git add *
git commit -m "Initial Commit of Dev Global to Global"
git push origin Global
git pull origin Global

#Setup Custom
& $cli --server $server --token $cliToken --action addBranch --project "CORE" --repository 'v5' --branch "Custom" --id $commit
git pull
git checkout Custom
git pull origin Custom
Move-Item -Path .\.git -Destination C:\core\.git -Force
Robocopy C:\core\Custom C:\core\mainline /mir /mt
Get-ChildItem -Filter *.pj -Force -Recurse | Remove-Item -Force
Move-Item -Path C:\core\.git -Destination .\.git -Force
git add *
git commit -m "Initial Commit of Dev Custom to Custom"
git push origin Custom
git pull origin Custom

#Setup Architecture
& $cli --server $server --token $cliToken --action addBranch --project "CORE" --repository 'v5' --branch "Architecture" --id $commit
git pull
git checkout Architecture
git pull origin Architecture
Move-Item -Path .\.git -Destination C:\core\.git -Force
Robocopy C:\core\ArchA C:\core\mainline /mir /mt
Get-ChildItem -Filter *.pj -Force -Recurse | Remove-Item -Force
Move-Item -Path C:\core\.git -Destination .\.git -Force
git add *
git commit -m "Initial Commit of Dev ArchA to Architecture"
git push origin Architecture
git pull origin Architecture
