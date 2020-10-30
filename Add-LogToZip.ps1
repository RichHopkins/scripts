function Add-Zip
{
	param
	(
		[string]$zipfilename,
		[string]$newfile
	)
	
	if (-not (test-path($zipfilename)))
	{
		set-content $zipfilename ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18))
		(dir $zipfilename).IsReadOnly = $false
	}
	
	$shellApplication = new-object -com shell.application
	$zipPackage = $shellApplication.NameSpace($zipfilename)
	write-output "attempting to add $newfile to $zipfilename"
	$zipPackage.MoveHere($newfile, 16)
	Start-Sleep -milliseconds 500
}

$logPaths = @("\\TXV8JBEQNQ01\ServerBox\jboss\soa-p-5.3.1.GA-UTIL\jboss-as\server\production\log", "\\TXV8JBEQNQ02\ServerBox\JBoss\soa-p-5.3.1.GA\jboss-as\server\production\log", "\\TXV8JBEQNQ02\ServerBox\JBoss\brms-p-5.3.1.GA\jboss-as\server\production\log")
foreach ($logPath in $logPaths)
{
	$logFiles = Get-ChildItem $logPath -filter "server.log.2*"
	foreach ($logFile in $logFiles)
	{
		$inputFile = $logFile.FullName
		#$fileInfo = Get-Item $inputFile
		#TODO: Add code to notify SM Team when Log Files are too big
		$zipPath = Join-Path -Path $logPath -ChildPath "server.log.zip"
		Add-Zip -zipfilename $zipPath -newfile $inputFile
	}
}