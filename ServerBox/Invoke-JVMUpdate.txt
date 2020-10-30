$servers = @("TXV12CFEQNC01", "TXV12CFEQNC02", "TXV12CFEQNC05")

$oldText = "-Djava.util.logging.config.file={application.home}/lib/logging.properties"
$newText = "-Djava.util.logging.config.file={application.home}/lib/logging.properties -Dcom.sun.xml.bind.v2.bytecode.ClassTailor.noOptimize=true "
$pattern = "ClassTailor.noOptimize=true"

foreach ($server in $servers) {
	Get-Service -Name "Adobe CF2016 ?" -ComputerName $server | Stop-Service
	1 .. 4 | %{
		$file = "\\$server\d$\ServerBox\Servers\ColdFusion\cfusion$_\bin\jvm.config"
		$ChangeReq = select-string -path $file -pattern $pattern
		if ($ChangeReq) {
			"Changes found in $file , skipping overwrite" >> "error.log"
		} Else {
			"Replacing content on file $file"
			(Get-Content $file).replace($oldText, $newText) | Set-Content $file
			#Invoke-Item $file
		}
	}
	Get-Service -Name "Adobe CF2016 ?" -ComputerName $server | Start-Service
}