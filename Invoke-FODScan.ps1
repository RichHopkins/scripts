Import-Module eqDevOps
Set-Location -path "D:\Fortify"
& git pull
$jenkinsHome = $env:JENKINS_HOME
$jobName = $env:JOB_NAME
$vendor = ($jobName -replace 'Fortify ', '') -replace ' Test', ''
Remove-Item "$jenkinsHome\workspace\$jobName" -Force -Recurse
$dirsDel = Get-ChildItem "$jenkinsHome\workspace\$jobName\*" -Directory
ForEach ($dir in $dirsDel) {
	Remove-Item $dir -Force -Recurse
}
$Dirs = Invoke-Sqlcmd2 -ServerInstance txv12sqeqnc21 -Database DevTools -Query "SELECT path FROM FODDirs WHERE vendor = `'$vendor`'"
ForEach ($dir in $Dirs.path) {
	$newDir = $dir -replace "D:\\Fortify", "$jenkinsHome\workspace\$jobName"
	Robocopy $dir $newDir /e /mt
}
$Files = Invoke-Sqlcmd2 -ServerInstance txv12sqeqnc21 -Database DevTools -Query "SELECT path FROM FODFiles WHERE vendor = `'$vendor`'"
ForEach ($file in $Files.path) {
	$file -match '.*\\(.*)\\'
	$dirPath = $matches[0]
	$newDir = $dirPath -replace "D:\\Fortify", "$jenkinsHome\workspace\$jobName"
	$newFile = $file -replace "D:\\Fortify", "$jenkinsHome\workspace\$jobName"
	If (!(Test-Path $newDir)) {
		New-Item -Path $newDir -ItemType Directory
	}
	Copy-Item $file $newFile -Force
}