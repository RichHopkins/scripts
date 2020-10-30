[string]$currentVersinon = 'release/12.02'
[string]$newVersion = 'release/12.03'
[string]$userName = "svc-mks.jenkins"
[string]$apiToken = "115b1c5a3871a02fa7d230a04b299896ff"
[string]$server = "jenkins.hq.reotrans.com"
[string]$jobToken = "Password1"


Import-Module eqDevOps

#kick off one last Deploy DB job in DevInt/Alpha
$jobNames = @(
	"DevInt%20-%20Deploy%20DB",
	"Alpha%20-%20Deploy%20DB"
)

foreach ($jobName in $jobNames) {
	$params = @{
		uri = "https://$server/job/$jobName/polling?token=$jobToken"
		Method = "Get"
		Headers = @{
			Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($userName):$($apiToken)"))
		}
	}
	Write-Output "Polling $jobName"
	Invoke-Restmethod @params | Out-Null
}

#Clear out unneeded binary data
$binaryDirs = @("\\isilon-hq-dfw\devintreo\inetpub\wwwroot\file_library\properties",
	"\\isilon-hq-dfw\devintreo\inetpub\mks-binaries-alpha\file_library\properties",
	"\\isilon-hq-dfw\devintreo\inetpub\mks-binaries-alpha\report_temp",
	"\\isilon-hq-dfw\devintreo\inetpub\wwwroot\file_library\properties",
	"\\isilon-hq-dfw\devintreo\inetpub\mks-binaries-alpha\file_library\properties",
	"\\isilon-hq-dfw\alphareo\inetpub\wwwroot\file_library\properties",
	"\\isilon-hq-dfw\alphareo\inetpub\mks-binaries-alpha\file_library\properties",
	"\\isilon-hq-dfw\alphareo\inetpub\mks-binaries-alpha\report_temp",
	"\\isilon-hq-dfw\AlphaSPO\inetpub\wwwroot\file_library\properties",
	"\\isilon-hq-dfw\AlphaSPO\inetpub\mks-binaries-alpha\file_library\properties")

foreach ($binaryDir in $binaryDirs) {
	Remove-Item -Path "$binaryDir\*" -Recurse -Force
}

#Update all jobs that use Git to use the new release version
$jenkinsDirs = @(Get-ChildItem -Path "\\jenkins\d$\Jenkins\jobs" -Directory)

foreach ($jenkinsDir in $jenkinsDirs) {
	$jobPath = $jenkinsDir.FullName
	if (Test-Path "$jobPath\config.xml") {
		if (Get-Content "$jobPath\config.xml" | Select-String -Pattern '<scm class="hudson.plugins.git.GitSCM"') {
			$config = [System.IO.File]::ReadAllText("$jobPath\config.xml").Replace($currentVersinon, $newVersion)
			[System.IO.File]::WriteAllText("$jobPath\config.xml", $config)
		}
	}
}

#Update Clear Cache jobs
$cacheDir = "\\jenkins\d$\Jenkins\jobs\Clear Cache"
if (Test-Path "$cacheDir\config.xml") {
	$config = [System.IO.File]::ReadAllText("$jobPath\config.xml").Replace($currentVersinon.Replace('release/', ''), $newVersion.Replace('release/', ''))
	[System.IO.File]::WriteAllText("$jobPath\config.xml", $config)
}

#turn Alpha builds on/off
$enabledString = @"
  <authToken>Password1</authToken>
  <triggers>
    <hudson.triggers.TimerTrigger>
      <spec>0 0,6,12,18 * * *</spec>
    </hudson.triggers.TimerTrigger>
  </triggers>
"@

$disabledString = @"
  <authToken>Password1</authToken>
  <triggers/>
"@

#Disable Alpha job
$config = [System.IO.File]::ReadAllText("\\jenkins\d$\Jenkins\jobs\Alpha - Build\config.xml").Replace($enabledString, $disabledString)
[System.IO.File]::WriteAllText("\\jenkins\d$\Jenkins\jobs\Alpha - Build\config.xml", $config)

#Update release.txt
$config = [System.IO.File]::ReadAllText("\\jenkins\d$\workspace\config\Release.txt").Replace($currentVersinon.Replace('release/', ''), $newVersion.Replace('release/', ''))
[System.IO.File]::WriteAllText("\\jenkins\d$\workspace\config\Release.txt", $config)

#Update Acceptance Test properties
$config = [System.IO.File]::ReadAllText("\\cahwtvsel128\c$\acceptancesuite\DevInt\Resources\config.properties").Replace($currentVersinon.Replace('release/', ''), $newVersion.Replace('release/', ''))
[System.IO.File]::WriteAllText("\\cahwtvsel128\c$\acceptancesuite\DevInt\Resources\config.properties", $config)

#Update reotrans database QA user passwords
$query = @"
update person set password ='0RMLPK1Q:"N+FIB3Z.S4&B0', unsuccessful_login_attempts = 0 ,isTempPassword=0 where person_id in(1907489, 1150406, 1150570)
"@
Invoke-Sqlcmd2 -ServerInstance "DSN_DEV_Reotrans" -Database "reotrans" -Query $query

#BRMS Stuff will go here

Get-Service -Name "jenkins" -ComputerName "jenkins" | Restart-Service
Get-Service -Name "jenkins" -ComputerName "jenkins2" | Restart-Service
