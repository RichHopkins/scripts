Set-Location C:\Jenkins\automationws
$proc = Start-Process "cmd.exe" -ArgumentList "/c C:\Jenkins\automationws\testng_automation.bat" -PassThru
$handle = $proc.Handle
$proc.WaitForExit()

if ($proc.ExitCode -eq 0) {
	Invoke-Command -ComputerName TXV8DOEQNC01 -ScriptBlock {
		Set-Location "C:\Program Files\Java\jdk1.8.0_92\jre\bin"
		.\java -jar D:\apps\Jenkins\war\WEB-INF\jenkins-cli.jar -s https://jenkins1.eqci/job/BUILD_Alpha/ enable-job "BUILD_Alpha"
	}
} else {
	Invoke-Command -ComputerName TXV8DOEQNC01 -ScriptBlock {
		Set-Location "C:\Program Files\Java\jdk1.8.0_92\jre\bin"
		.\java -jar D:\apps\Jenkins\war\WEB-INF\jenkins-cli.jar -s https://jenkins1.eqci/job/BUILD_Alpha/ disable-job "BUILD_Alpha"
	}
	
	$results = Get-ChildItem "\\CACRPFS01\NetShare\QA\Jenkins\result*.html"
	$file = $results | Sort-Object LastWriteTime | Select-Object -Last 1
	$strFile = $file.FullName
	$subject = "DevInt Acceptance Test Failure!"
	$body = "There was an error during DevInt Acceptance, please check the following Selenium results file for details:<BR><BR>"
	$body += "$strFile<BR><BR>"
	$body += "Equator DevOps Team<BR>"
	$body += "eqdevops@equator.com<BR><BR>"
	Send-MailMessage -SmtpServer "smtp-dev" -To "_COE.EntArch.DevOps@equator.com" -Cc "_COE.EntArch.DevOps@equator.com" -From "_COE.EntArch.DevOps@equator.com" -Subject $subject -Body $body -BodyAsHtml -Priority High
	exit 1
}