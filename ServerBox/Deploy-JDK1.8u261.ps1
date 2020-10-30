#Copy JDK into place
Stop-Service ado*
robocopy "\\isilon-hq-dfw\DevArchive\ServerBox\Java\JDK\jdk1.8.0_261" "D:\ServerBox\Java\JDK\jdk1.8.0_261" /e /mt
#Copy old cacerrs file into the new JDK
Copy-Item 'D:\ServerBox\Java\JDK\jdk.1.8.0_151\jre\lib\security\cacerts' 'D:\ServerBox\Java\JDK\jdk1.8.0_261\jre\lib\security\cacerts' -Force
$files = Get-ChildItem "D:\ServerBox\Servers\ColdFusion\cf*\bin\jvm.config" -File
foreach ($file in $files) {
	#backup jvm.config before setting the new path
	Copy-Item -Path $file.FullName -Destination "$($file.FullName).bak" -Force
	(Get-Content $file).replace('jdk.1.8.0_151', 'jdk1.8.0_261') | Set-Content $file
}
Start-Service ado*