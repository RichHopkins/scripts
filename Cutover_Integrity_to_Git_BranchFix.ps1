[string]$cliToken = 'put your key here'
[string]$cliPath = 'C:\atlassian-cli-7.9.0'
[string]$serverRoot = 'https://eqalm.hq.reotrans.com'
[string]$smPath = "C:\ServiceMart"

$cli = "$cliPath\bitbucket.bat"
$server = "$serverRoot/bitbucket"

#prep Integrity variants
# Start-Process "si.exe" -ArgumentList "createsandbox -R --yes --shared --project=/servicemart/project.pj $smPath\mainline"
# Start-Process "si.exe" -ArgumentList "createsandbox -R --yes --shared --project=/servicemart/project.pj --devpath=12.02-Servicemart_Rem_Dev $smPath\REM"
# Start-Process "si.exe" -ArgumentList "createsandbox -R --yes --shared --project=/servicemart/project.pj --devpath=12.03-Servicemart_Beta $smPath\Beta"
# Start-Process "si.exe" -ArgumentList "createsandbox -R --yes --shared --project=/servicemart/project.pj --devpath=12.04-Servicemart_Dev_Int $smPath\DevInt"
# Start-Process "si.exe" -ArgumentList "createsandbox -R --yes --shared --project=/servicemart/project.pj --devpath=12.03-Servicemart_Dev $smPath\Dev"

Start-Process "si.exe" -ArgumentList "resync --sandbox=$smPath\REM\project.pj" -Wait
Start-Process "si.exe" -ArgumentList "resync --sandbox=$smPath\Beta\project.pj" -Wait

#resync Integrity variants
# $dirs = Get-ChildItem -Path "C:\ServiceMart" -Directory
# foreach ($dir in $dirs) {
#   Start-Process "si.exe" -ArgumentList "resync --sandbox=$dir\project.pj" -Wait
# }

#create SOA
if (-not (Test-Path "C:\git")) {
  mkdir "C:\git"
}
Set-Location "C:\git"
git clone https://eqalm.hq.reotrans.com/bitbucket/scm/sm/soa.git
Set-Location "C:\git\soa"
& $cli --server $server --token $cliToken --action removeBranch --project "SM" --repository SOA --branch "release/12.02"
& $cli --server $server --token $cliToken --action removeBranch --project "SM" --repository SOA --branch "release/12.03"
$commit = git rev-list --simplify-by-decoration -1 HEAD
& $cli --server $server --token $cliToken --action addBranch --project "SM" --repository SOA --branch "release/12.02.07" --id $commit
git pull
git checkout release/12.02.07
git pull origin release/12.02.07
Move-Item -Path .\.git -Destination C:\git\.git -Force
Robocopy C:\ServiceMart\REM\project C:\git\soa /mir /mt
Get-ChildItem -Filter *.pj -Force -Recurse | Remove-Item -Force
Move-Item -Path C:\git\.git -Destination .\.git -Force
git add *
git commit -m "Initial Commit of REM to release/12.02.07"
git push origin release/12.02.07
git pull origin release/12.02.07
& $cli --server $server --token $cliToken --action addBranch --project "SM" --repository SOA --branch "release/12.03" --id $commit
git pull
git checkout release/12.03
git pull origin release/12.03
Move-Item -Path .\.git -Destination C:\git\.git -Force
Robocopy C:\ServiceMart\Beta\project C:\git\soa /mir /mt
Get-ChildItem -Filter *.pj -Force -Recurse | Remove-Item -Force
Move-Item -Path C:\git\.git -Destination .\.git -Force
git add *
git commit -m "Initial Commit of Beta to release/12.03"
git push origin release/12.03
git pull

#create document
Set-Location "C:\git"
git clone https://eqalm.hq.reotrans.com/bitbucket/scm/sm/document.git
Set-Location "C:\git\document"
& $cli --server $server --token $cliToken --action removeBranch --project "SM" --repository document --branch "release/12.02"
& $cli --server $server --token $cliToken --action removeBranch --project "SM" --repository document --branch "release/12.03"
$commit = git rev-list --simplify-by-decoration -1 HEAD
& $cli --server $server --token $cliToken --action addBranch --project "SM" --repository document --branch "release/12.02.07" --id $commit
git pull
git checkout release/12.02.07
git pull origin release/12.02.07
Move-Item -Path .\.git -Destination C:\git\.git -Force
Robocopy C:\ServiceMart\REM\document C:\git\document /mir /mt
Get-ChildItem -Filter *.pj -Force -Recurse | Remove-Item -Force
Move-Item -Path C:\git\.git -Destination .\.git -Force
git add *
git commit -m "Initial Commit of REM to release/12.02.07"
git push origin release/12.02.07
git pull origin release/12.02.07
& $cli --server $server --token $cliToken --action addBranch --project "SM" --repository document --branch "release/12.03" --id $commit
git pull
git checkout release/12.03
git pull origin release/12.03
Move-Item -Path .\.git -Destination C:\git\.git -Force
Robocopy C:\ServiceMart\Beta\document C:\git\document /mir /mt
Get-ChildItem -Filter *.pj -Force -Recurse | Remove-Item -Force
Move-Item -Path C:\git\.git -Destination .\.git -Force
git add *
git commit -m "Initial Commit of Beta to release/12.03"
git push origin release/12.03
git pull

#create the rest of the Fuse repos
$dirs = Get-ChildItem -Path "C:\ServiceMart\REM\ng\projects" -Directory
foreach ($dir in $dirs) {
  $repo = $dir.Name
  Set-Location "C:\git"
  git clone https://eqalm.hq.reotrans.com/bitbucket/scm/sm/$repo.git
  Set-Location "C:\git\$repo"
  & $cli --server $server --token $cliToken --action removeBranch --project "SM" --repository $repo --branch "release/12.02"
  & $cli --server $server --token $cliToken --action removeBranch --project "SM" --repository $repo --branch "release/12.03"
  $commit = git rev-list --simplify-by-decoration -1 HEAD
  & $cli --server $server --token $cliToken --action addBranch --project "SM" --repository $repo --branch "release/12.02.07" --id $commit
  git pull
  git checkout release/12.02.07
  git pull origin release/12.02.07
  Move-Item -Path .\.git -Destination C:\git\.git -Force
  Robocopy C:\ServiceMart\REM\ng\projects\$repo C:\git\$repo /mir /mt
  Get-ChildItem -Filter *.pj -Force -Recurse | Remove-Item -Force
  Move-Item -Path C:\git\.git -Destination .\.git -Force
  git add *
  git commit -m "Initial Commit of REM to release/12.02.07"
  git push origin release/12.02.07
  git pull origin release/12.02.07
  & $cli --server $server --token $cliToken --action addBranch --project "SM" --repository $repo --branch "release/12.03" --id $commit
  git pull
  git checkout release/12.03
  git pull origin release/12.03
  Move-Item -Path .\.git -Destination C:\git\.git -Force
  Robocopy C:\ServiceMart\Beta\ng\projects\$repo C:\git\$repo /mir /mt
  Get-ChildItem -Filter *.pj -Force -Recurse | Remove-Item -Force
  Move-Item -Path C:\git\.git -Destination .\.git -Force
  git add *
  git commit -m "Initial Commit of Beta to release/12.03"
  git push origin release/12.03
  git pull
}