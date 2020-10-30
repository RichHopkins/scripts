if (Get-Process -Name integrity*) {
	#Write-Output "Integrity running"
} else {
	Send-MailMessage -SmtpServer "smtp-dev" -To 'richard.hopkins@equator.com' -From "eqdevops@equator.com" -Subject "FNMA Integrity Offline!" -Body "Integrity is offline!" -BodyAsHtml $true -Priority High
}