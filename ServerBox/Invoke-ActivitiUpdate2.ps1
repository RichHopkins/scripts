[CmdletBinding()]
param
(
	[string]$encryptedPass
)

$serverXmls = Get-ChildItem -Path "D:\ServerBox\Servers\ColdFusion\cfus*\runtime\conf\server.xml"

ForEach ($serverXml in $serverXmls) {
	$oldString = @"
                  initialSize=""20""
                  maxWaitMillis=""15000""
                  maxTotal=""75""
                  maxIdle=""20""
                  testOnBorrow=""true""
                  validationQuery=""select 1""
"@
	$newString = @"
                  factory=""com.equator.util.tomcat.EncryptedDataSourceFactory""
                  username=""cf.reotrans""
                  password=""$encryptedPass""
"@
	(Get-Content $serverXml).replace($oldString, $newString) | Set-Content $serverXml
}

$dirs = Get-ChildItem -Path "D:\ServerBox\Servers\ColdFusion\cfus*"
ForEach ($dir in $dirs) {
	$isilon = "\\isilon-hq-dfw\DevArchive\ServerBox\Servers\ColdFusion\cfusion"
	Copy-Item -Path "$isilon\runtime\lib\Equator-TomcatUtils-0.1.0.jar" -Destination "$dir\runtime\lib\Equator-TomcatUtils-0.1.0.jar" -Force
	If ((Test-Path "$dir\runtime\lib\org\apache\tomcat\tomcat-jdbc\8.5.11") -eq $false) {
		New-Item -Path "$dir\runtime\lib\org\apache\tomcat\tomcat-jdbc\8.5.11" -ItemType Directory
	}
	Copy-Item -Path "$isilon\runtime\lib\org\apache\tomcat\tomcat-jdbc\8.5.11\tomcat-jdbc-8.5.11.jar" -Destination "$dir\runtime\lib\org\apache\tomcat\tomcat-jdbc\8.5.11\tomcat-jdbc-8.5.11.jar" -Force
	If ((Test-Path "$dir\runtime\lib\org\apache\tomcat\tomcat-juli\8.5.11") -eq $false) {
		New-Item -Path "$dir\runtime\lib\org\apache\tomcat\tomcat-juli\8.5.11" -ItemType Directory
	}
	Copy-Item -Path "$isilon\runtime\lib\org\apache\tomcat\tomcat-juli\8.5.11\tomcat-juli-8.5.11.jar" -Destination "$dir\runtime\lib\org\apache\tomcat\tomcat-juli\8.5.11\tomcat-juli-8.5.11.jar" -Force
}