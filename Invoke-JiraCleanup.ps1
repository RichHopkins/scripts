#STOP ALL SERVICES
Stop-Service JIRASoftware310816150829
Stop-Service Confluence010916111809
Stop-Service Atlassian*
#REMOVE ANY LEFT OVER LOCK FILES
If (Test-Path 'D:\Atlassian\ApplicationData\Jira\.jira-home.lock') { Remove-Item 'D:\Atlassian\ApplicationData\Jira\.jira-home.lock' -Force }
If (Test-Path 'D:\Atlassian\ApplicationData\Confluence\lock') { Remove-Item 'D:\Atlassian\ApplicationData\Confluence\lock' -Force }
If (Test-Path 'D:\Atlassian\ApplicationData\BitBucket\.lock') { Remove-Item 'D:\Atlassian\ApplicationData\BitBucket\.lock' -Force }
If (Test-Path 'D:\Atlassian\ApplicationData\Crucible\var\fisheye.lck') { Remove-Item 'D:\Atlassian\ApplicationData\Crucible\var\fisheye.lck' -Force }
#START SERVICES BACK UP
Start-Service JIRASoftware310816150829
Start-Sleep -Seconds 300
Start-Service Confluence010916111809
Start-Sleep -Seconds 300
Start-Service AtlassianBit*
Start-Sleep -Seconds 300
Start-Service 'Atlassian Crucible'