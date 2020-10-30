Invoke-WebRequest -Uri "https://jenkins/view/DevInt/job/DevInt%20-%20LoadRunner/buildWithParameters?token=Password1" -Method Post
Start-Sleep -seconds 300
Invoke-WebRequest -Uri "https://jenkins/view/DevInt/job/DevInt%20-%20Selenium/buildWithParameters?token=Password1" -Method Post 