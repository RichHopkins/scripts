$filePath = "C:\Windows\System32\inetsrv\config\applicationHost.config"
$strOld = 'add name="cfmHandler" path="*.cfm" verb="*"'
$strNew = 'add name="cfmHandler" path="*.cfm" verb="GET,HEAD,POST"'
Get-Content -Path $filePath | Set-Content -Path "$filePath.bak" -Force
(Get-Content -Path $filePath).Replace($strOld, $strNew) | Set-Content -Path $filePath -Force