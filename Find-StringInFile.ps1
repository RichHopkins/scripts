param
(
	[Parameter(Mandatory = $false)]
	[string[]]$path = "D:\ServerBox\Servers\JRun4\logs\cfusion9-?-out.log",
	[string[]]$pattern = "Transformer not found"
)

$results = Select-String -Path $path -Pattern $pattern

if ($results) {
	foreach ($result in $results) {
		$arrResult = $result -split ":"
		$logPath = $arrResult[0]
		$logLine = $arrResult[1]
		$codePath = $arrResult[$arrResult.Length - 1]
		$body = @"

$pattern was found in $logPath on line $logLine.
The code error was: $codePath
		

"@
		Send-MailMessage -Attachments $logPath -SmtpServer "smtp-dev" -To "_COE.EntArch.DevOps@equator.com", "Alexander.Slavin@equator.com", "Teeranit.Ruangdet@equator.com", "Karun.Subramanian@equator.com" -From "_COE.EntArch.DevOps@equator.com" -Subject "Alpha Transformer not found!" -Priority High -Body $body
	}
}