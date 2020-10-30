Import-Module eqDevOps

$strComputer = $env:COMPUTERNAME
Write-ToSlack -BotName $strComputer -Channel '#devops-devint' -Message '@rich @sintayow: QA Acceptance machine just rebooted!'
Send-MailMessage -SmtpServer 'smtp-dev' -To "_COE.EntArch.DevOps@equator.com", "Nikhil.Prakash@equator.com", "Anand.Thampi@equator.com" -From "eqDevOps <_COE.EntArch.DevOps@equator.com>" -Subject "QA Acceptance System Reboot" -Body "$strComputer just rebooted!"