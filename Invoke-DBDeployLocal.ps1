Import-Module eqDevOps

#capture Jenkins params
$environment = $env:environment
$cliToken = $env:cliToken
$gitJob = $env:gitJob

#declare script arrays
[System.Collections.ArrayList]$changeLogEntries = @()
[System.Collections.ArrayList]$orderedScriptList = @()
[System.Collections.ArrayList]$specialScriptList = @()
[System.Collections.ArrayList]$uTables = @()
[System.Collections.ArrayList]$uTableAlter = @()
[System.Collections.ArrayList]$uViews = @()
[System.Collections.ArrayList]$uFunctions = @()
[System.Collections.ArrayList]$uStoredProcedures = @()
[System.Collections.ArrayList]$uScripts = @()
[System.Collections.ArrayList]$uIndexes = @()
[System.Collections.ArrayList]$uOther = @()

#Setup other needed variables
$serverRoot = 'https://eqalm.hq.reotrans.com'
$cliPath = 'C:\atlassian-cli'
$dbRoot = "C:\Database$environment"
$buildTime = Get-Date -Format "yyyy-MM-dd_HH-mm"
$dbBuildDir = "$dbRoot\_builds\$buildTime"
$dbData = "$dbBuildDir\_data"

#region Script Functions and Classes
#changeLogEntry will hold all the information for each script in the build
class changeLogEntry {
	[string]$commit
	[string]$author
	[string]$authorEmail
	[string]$committer
	[string]$committerEmail
	[string]$scriptPath
	[string]$backupPath
	[string[]]$jiraKeys
	[bool]$releaseInstruction
	[string]$releaseInstructionPath
}

#This function will read the change log from the last Git resync and spit out an array of changeLogEntry objects
function Read-GitChangeLog {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true,
				   Position = 0)]
		[ValidateSet('ARCH', 'CORE', 'DB', 'DBDEMO', 'DO', 'PRO', 'QA', 'REL', 'SM')]
		[string]$project,
		[Parameter(Mandatory = $true,
				   Position = 1)]
		[string]$repository,
		[Parameter(Mandatory = $true,
				   Position = 2)]
		[ValidateScript({
				Test-Path $_
			})]
		[string]$logPath
	)

	$projectRoot = "$dbRoot\$repository"
	[System.Collections.ArrayList]$changeLogEntriesTemp = @()
	$log = Get-Content $logPath
	for ($i = 0; $i -le ($log.Length - 1); $i++) {
		if ($log[$i] -match "commit .{40}") {
			$commit = $log[$i] -replace "commit ", ""
			$jiraKeys = (& $cliPath\bitbucket.bat --server $serverRoot/bitbucket --token $cliToken --action getCommit --project $project --repository $repository --id $commit | Select-String 'Jira keys . . . . . . . . . . : (. *)') -replace 'Jira keys . . . . . . . . . . : ', ''
			$jiraKeys = $jiraKeys -split ','
		}
		if ($log[$i] -match "author (.*) <([a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*)>") {
			$author = $matches[1].Trim()
			$authorEmail = $matches[2].Trim()
		}
		if ($log[$i] -match "committer (.*) <([a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*)>") {
			$committer = $matches[1].Trim()
			$committerEmail = $matches[2].Trim()
		}
		if ($log[$i] -match ":\d{6}") {
			$file = ($log[$i] -split "`t")[1] -replace '/', '\'
			$entry = [changeLogEntry]::new()
			$entry.commit = $commit
			$entry.author = $author
			$entry.authorEmail = $authorEmail
			$entry.committer = $committer
			$entry.committerEmail = $committerEmail
			$entry.scriptPath = "$projectRoot\$file"
			$entry.backupPath = "$dbBuildDir\$file"
			$entry.jiraKeys = $jiraKeys
			$changeLogEntriesTemp += $entry
		}
	}
	return $changeLogEntriesTemp
}

#Used to notify a scripts developer in case of a script error
function Send-DevErrorEmail {
	param
	(
		[string]$jiraIssue,
		[string]$usermail,
		[string]$commitermail,
		[string[]]$attach
	)

	$subject = "$($environment.ToUpper()) SQL SCRIPT FAILURE - $jiraIssue"
	switch ($environment) {
		"DevInt|Alpha" {
			$body = "There was an error when running the SQL script for your Jira Issue: <b><font color=red>$jiraIssue</b></font><BR>"
			$body += "Please see the attached log file for details.<BR><BR>"
			$body += "Contact DevOps for any assistance.<BR><BR>"
			$body += "Equator DevOps Team<BR>"
			$body += "eqdevops@equator.com<BR><BR>"
			$parameters = @{
				SmtpServer = "smtp-dev"
				To = $usermail
				Cc		   = "eqdevops@equator.com; $commitermail"
				From	   = "eqdevops@equator.com"
				Subject    = $subject
				Body	   = $body
				BodyAsHtml = $true
				Attachments = $attach
			}
		}
		"Beta|Stage|REM|Produection" {
			$body = "There was an error when running the SQL script for your Jira Issue: <b><font color=red>$jiraIssue</b></font><BR>"
			$body += "Please see the attached log file for details.<BR><BR>"
			$body += "Contact Release for any assistance.<BR><BR>"
			$body += "Equator Release Team<BR>"
			$body += "_release.engineer@equator.com<BR><BR>"
			$parameters = @{
				SmtpServer = "smtp-dev"
				To = $usermail
				Cc		   = "_release.engineer@equator.com; $commitermail"
				From	   = "_release.engineer@equator.com"
				Subject    = $subject
				Body	   = $body
				BodyAsHtml = $true
				Attachments = $attach
			}
		}
	}

	Send-MailMessage @parameters
}

#This function handles the actual execution of the SQL scripts
function Invoke-SQLScript {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[changeLogEntry]$entry
	)

	Write-Output "Running the following script:"
	Write-Output $entry
	#varable setup
	[string]$author = $entry.author
	[string]$authorEmail = $entry.authorEmail
	[string]$committerEmail = $entry.committerEmail
	[string]$scriptPath = $entry.scriptPath
	[string]$backupPath = $entry.backupPath
	[string]$sqlLogPath = "$backupPath.log"
	$jiraKeys = $entry.jiraKeys
	$jiraKeys = $jiraKeys -join ", "
	[void]($jiraKeys -match "(\w{1,10})-")
	if ($jiraProject) {
		$jiraProject = $matches[1]
	}

	if ($scriptPath -match "tables\\alter") {
		[void]($scriptPath -match "D:\\Database$environment\\.*\\(.*)\\.*\\.*\\")
	} else {
		[void]($scriptPath -match "D:\\Database$environment\\.*\\(.*)\\.*\\")
	}

	[string]$dbName = $matches[1]

	#this switch is used to populate the $dbServer variable based off $environment and $dbName
	switch ($environment) {
		"DevInt" {
			switch ($dbName) {
				"Activiti" {
					$dbServer = "TXV12SQEQNC22"
				}
				"Agent" {
					$dbServer = "TXV12SQEQNC22"
				}
				"ClientDB" {
					$dbServer = "TXV12SQEQNC22"
				}
				"ClientDB2" {
					$dbServer = "TXV12SQEQNC22"
				}
				"Configuration" {
					$dbServer = "TXV12SIEQNC21"
				}
				"CW_IMPORT" {
					$dbServer = "TXV12SQEQNC22"
				}
				"Environments" {
					$dbServer = "TXV12SQEQNC22"
				}
				"EPI" {
					$dbServer = "TXV12SQEQNC22"
				}
				"EQLogs" {
					$dbServer = "TXV12SQEQNC22"
				}
				"EQ_PROFILER" {
					$dbServer = "TXV12SQEQNC23"
				}
				"Equator_Meta" {
					$dbServer = "TXV12SQEQNC22"
				}
				"GeoCode" {
					$dbServer = "TXV12SQEQNC23"
				}
				"KeyMgmt" {
					$dbServer = "TXV12SQEQNC22"
				}
				"INTEGRATION" {
					$dbServer = "TXV12SQEQNC23"
				}
				"IssueTracker" {
					$dbServer = "TXV12SQEQNC23"
				}
				"Loan_Management" {
					$dbServer = "TXV12SQEQNC23"
				}
				"Muradb" {
					$dbServer = "TXV12SQEQNC22"
				}
				"OCWEN_EPI" {
					$dbServer = "TXV12SQEQNC22"
				}
				"Reap" {
					$dbServer = "TXV12SQEQNC23"
				}
				"Reports" {
					$dbServer = "TXV12SQEQNC22"
				}
				"Reotrans" {
					$dbServer = "TXV12SQEQNC22"
				}
				"Reotransreadonly_Audit" {
					$dbServer = "TXV12SQEQNC22"
				}
				"Rule_Matrix_Configuration" {
					$dbServer = "TXV12SQEQNC22"
				}
				"Seefusion" {
					$dbServer = "TXV12SQEQNC23"
				}
				"Segmentation" {
					$dbServer = "TXV12SQEQNC22"
				}
				"Servicemart" {
					$dbServer = "TXV12SQEQNC23"
				}
				"Website_Sessions" {
					$dbServer = "TXV12SQEQNC23"
				}
				"Configuration" {
					$dbServer = ""
				}
			}
		}
		"Alpha" {
			switch ($dbName) {
				"Activiti" {
					$dbServer = "TXV12SQEQNQ21"
				}
				"Agent" {
					$dbServer = "TXV12SQEQNQ21"
				}
				"ClientDB" {
					$dbServer = "TXV12SQEQNQ21"
				}
				"ClientDB2" {
					$dbServer = "TXV12SQEQNQ21"
				}
				"Configuration" {
					$dbServer = "TXV12SIEQNQ21"
				}
				"CW_IMPORT" {
					$dbServer = "TXV12SQEQNQ22"
				}
				"DBA" {
					$dbServer = "TXV12SQEQNQ22"
				}
				"Environments" {
					$dbServer = "TXV12SQEQNQ21"
				}
				"EPI" {
					$dbServer = "TXV12SQEQNQ21"
				}
				"EQLogs" {
					$dbServer = "TXV12SQEQNQ21"
				}
				"EQ_PROFILER" {
					$dbServer = "TXV12SQEQNQ22"
				}
				"Equator_Meta" {
					$dbServer = "TXV12SQEQNQ21"
				}
				"GeoCode" {
					$dbServer = "TXV12SQEQNQ22"
				}
				"KeyMgmt" {
					$dbServer = "TXV12SQEQNQ21"
				}
				"INTEGRATION" {
					$dbServer = "TXV12SQEQNQ22"
				}
				"IssueTracker" {
					$dbServer = "TXV12SQEQNQ22"
				}
				"Loan_Management" {
					$dbServer = "TXV12SQEQNQ22"
				}
				"Muradb" {
					$dbServer = "TXV12SQEQNQ21"
				}
				"OCWEN_EPI" {
					$dbServer = "TXV12SQEQNQ21"
				}
				"Reap" {
					$dbServer = "TXV12SQEQNQ22"
				}
				"Reports" {
					$dbServer = "TXV12SQEQNQ21"
				}
				"Reotrans" {
					$dbServer = "TXV12SQEQNQ21"
				}
				"Reotransreadonly" {
					$dbServer = "TXV12SQEQNQ21"
				}
				"Reotransreadonly_Audit" {
					$dbServer = "TXV12SQEQNQ21"
				}
				"Rule_Matrix_Configuration" {
					$dbServer = "TXV12SQEQNQ21"
				}
				"Seefusion" {
					$dbServer = "TXV12SQEQNQ22"
				}
				"Segmentation" {
					$dbServer = "TXV12SQEQNQ21"
				}
				"Servicemart" {
					$dbServer = "TXV12SQEQNQ22"
				}
				"Website_Sessions" {
					$dbServer = "TXV12SQEQNQ22"
				}
			}
		}
		"Beta"{
			switch ($dbName) {
				"database names" {
					$dbServer = "server name"
				}
			}
		}
		"Stage"{
			switch ($dbName) {
				"database names" {
					$dbServer = "server name"
				}
			}
		}
		"REM"{
			switch ($dbName) {
				"database names" {
					$dbServer = "server name"
				}
			}
		}
		"Production"{
			switch ($dbName) {
				"database names" {
					$dbServer = "server name"
				}
			}
		}
	}
	#copy the script to a backup location
	$filepath = Split-Path $backupPath -Parent
	If (-not (Test-Path $filepath)) {
		New-Item -Path $filepath -ItemType directory -Force | Out-Null
	}
	Copy-Item -Path $scriptPath -Destination $backupPath -Force
	#execute script from backup location and generate log there
	Write-Output "SQLCMD -S $dbServer -d $dbName -i $backupPath -I -o $sqlLogPath"
	& SQLCMD -S $dbServer -d $dbName -i $backupPath -I -o $sqlLogPath
	Write-Output ""
	#check log for errors
	$isError = Get-Content $sqlLogPath -WarningAction SilentlyContinue | Where-Object {
		$_ -match "Msg|HResult|Unexpected"
	} -WarningAction SilentlyContinue
	if ($isError) {
		#Open a Jira Bug issue for the error
		$summary = "$($environment.ToUpper()) SQL SCRIPT FAILURE - $jiraIssue"
		switch ($environment) {
			"DevInt|Alpha" {
				$description = "There was an error when running the SQL script for your Jira Issue: $jiraIssue`r`n"
				$description += "Please see the attached log file for details`r`n"
				$description += "Contact DevOps for any assistance`r`n"
				$description += "Equator DevOps Team`r`n"
				$description += "eqdevops@equator.com"
			}
			"Beta|Stage|REM|Produection" {
				$description = "There was an error when running the SQL script for your Jira Issue: $jiraIssue`r`n"
				$description += "Please see the attached log file for details`r`n"
				$description += "Contact Release for any assistance`r`n"
				$description += "Equator Release Team`r`n"
				$description += "_release.engineer@equator.com"
			}
		}
		Send-DevErrorEmail -jiraIssue $jiraKeys -usermail $authorEmail -commitermail $committerEmail -attach $sqlLogPath
		#& $cliPath\jira.bat --server $serverRoot/jira --user $jiraUser --password $jiraPass --action createIssue --issueType "Bug" --project $jiraProject --summary $summary --description $description --assignee $author
		#ENTER CODE HERE THAT GETS THE BUG ID JUST CREATED AS $issueID
		#& $cliPath\jira.bat --server $serverRoot/jira --user $jiraUser --password $jiraPass --action addAttachment --issue $issueID --file $sqlLogPath
		Write-Output "[ERROR] executing $backupPath, please check $sqlLogPath"
	}
}
#endregion

#select the folder from the most recent Git build and read its change log
foreach ($project in $projects) {
	$gitJobPath = "D:\Jenkins\jobs\$gitJob-$project\builds"
	$buildDir = Get-ChildItem -Path $gitJobPath -Directory | Sort-Object CreationTime -Descending | Select-Object -First 1
	$logPath = "$($buildDir.FullName)\changeLog.xml"
	Write-Output "Reading through the changelog at:  $($buildDir.FullName)\changeLog.xml"
	$changeLogEntries += Read-GitChangeLog -project DB -repository $project -logPath $logPath
}

#if changes found, process them
if ($changeLogEntries) {
	Write-Output "Getting Release Instructions"
	foreach ($key in ($changeLogEntries.jiraKeys | Select-Object -Unique)) {
		$attachCheck = (& $cliPath\jira.bat --server $serverRoot/jira --user $jiraUser --password $jiraPass --action getAttachmentList --issue $key) -replace "\d{1,2} attachments for issue: .*", '' | ConvertFrom-Csv
		if ($attachCheck.Name -eq "ReleaseInstructions.xml") {
			if (!(Test-Path "$dbData\$key")) {
				New-Item -Path "$dbData\$key" -ItemType directory -Force | Out-Null
			}
			Push-Location "$dbData\$key"
			& $cliPath\jira.bat --server $serverRoot/jira --user $jiraUser --password $jiraPass --action getAttachment --issue $key --file "ReleaseInstructions.xml"
			Pop-Location
			Write-Output "Updating `$changeLogEntries with Release Instruction data"
			foreach ($entry in $changeLogEntries) {
				if ($entry.jiraKeys -match $key) {
					$entry.releaseInstruction = $true
					$entry.releaseInstructionPath = "$dbData\$key\ReleaseInstructions.xml"
				}
			}
		}
	}

	Write-Output "Parsing Release Instruction files"
	foreach ($releaseInstruction in ($changeLogEntries.releaseInstructionPath | Select-Object -Unique)) {
		[bool]$specialInstructions = $false
		$xml = Get-XMLFile -xmlFile $releaseInstruction
		if ($xml.ReleaseInstructions.Instructions) {
			[bool]$specialInstructions = $true
		}
		$xpath = "/ReleaseInstructions/database/dataScripts"
		If ($xml.ReleaseInstructions.database.dataScripts.environment.name -contains "ALL") {
			$allEnvScripts = (Select-Xml -Xml $xml -XPath "$xpath/environment[@name='ALL']" -ErrorAction SilentlyContinue).get_node()
		}
		if ($allEnvScripts.script.Longrunning -match "True" -or $allEnvScripts.script.Longrunning -match "True" -or $allEnvScripts.script.Instructions -ne $null) {
			[bool]$specialInstructions = $true
		}
		Write-Output "Special Instructions = $specialInstructions"
		if ($allEnvScripts -and $specialInstructions -eq $false) {
			foreach ($script in $allEnvScripts.script) {
				$scriptPath = ($script.path).Replace('/database', $dbRoot).Replace('/', '\')
				foreach ($entry in $changeLogEntries) {
					if ($entry.scriptPath -match ($scriptPath).Replace('\', '\\')) {
						$orderedScriptList += $entry
					}
				}
			}
		} elseif ($allEnvScripts -and $specialInstructions -eq $true) {
			foreach ($script in $allEnvScripts.script) {
				$scriptPath = ($script.path).Replace('/database', $dbRoot).Replace('/', '\')
				foreach ($entry in $changeLogEntries) {
					if ($entry.scriptPath -match ($scriptPath).Replace('\', '\\')) {
						$specialScriptList += $entry
					}
				}
			}
		}
		If ($xml.ReleaseInstructions.database.dataScripts.environment.name -contains $environment) {
			$envScripts = (Select-Xml -Xml $xml -XPath "$xpath/environment[@name='$environment']" -ErrorAction SilentlyContinue).get_node()
		}
		if ($envScripts.script.Longrunning -match "True" -or $envScripts.script.Longrunning -match "True" -or $envScripts.script.Instructions -ne $null) {
			[bool]$specialInstructions = $true
		}
		if ($envScripts -and $specialInstructions -eq $false) {
			foreach ($script in $envScripts.script) {
				$scriptPath = ($script.path).Replace('/database', $dbRoot).Replace('/', '\')
				for ($i = 0; $i -lt $changeLogEntries.Count; $i++) {
					$entry = $changeLogEntries[$i]
					if ($entry.scriptPath -match ($scriptPath).Replace('\', '\\')) {
						$orderedScriptList += $entry
					}
				}
			}
		} elseif ($envScripts -and $specialInstructions -eq $true) {
			foreach ($script in $envScripts.script) {
				$scriptPath = ($script.path).Replace('/database', $dbRoot).Replace('/', '\')
				foreach ($entry in $changeLogEntries) {
					if ($entry.scriptPath -match ($scriptPath).Replace('\', '\\')) {
						$specialScriptList += $entry
					}
				}
			}
		}
	}

	for ($i = 0; $i -lt $changeLogEntries.Count; $i++) {
		$entry = $changeLogEntries[$i]
		if ($entry.scriptPath.ToLower().Contains("\tables\alter\") -and ($orderedScriptList -contains $entry) -eq $false) {
			$uTableAlter += $entry
		} elseif ($entry.scriptPath.ToLower().Contains("\tables\") -and ($orderedScriptList -contains $entry) -eq $false) {
			$uTables += $entry
		} elseif ($entry.scriptPath.ToLower().Contains("\views\") -and ($orderedScriptList -contains $entry) -eq $false) {
			$uViews += $entry
		} elseif ($entry.scriptPath.ToLower().Contains("\functions\") -and ($orderedScriptList -contains $entry) -eq $false) {
			$uFunctions += $entry
		} elseif ($entry.scriptPath.ToLower().Contains("\storedprocedures\") -and ($orderedScriptList -contains $entry) -eq $false) {
			$uStoredProcedures += $entry
		} elseif ($entry.scriptPath.ToLower().Contains("\scripts\") -and ($orderedScriptList -contains $entry) -eq $false) {
			$uScripts += $entry
		} elseif ($entry.scriptPath.ToLower().Contains("\indexes\") -and ($orderedScriptList -contains $entry) -eq $false) {
			$uIndexes += $entry
		} elseif (($orderedScriptList -contains $entry) -eq $false) {
			$uOther += $entry
		}
	}

	if ($orderedScriptList.Count -gt 0) {
		Write-Output "Running ordered scripts"
		foreach ($entry in $orderedScriptList) {
			Invoke-SQLScript $entry
		}
	}
	if ($uTables.Count -gt 0) {
		Write-Output "Running table scripts"
		foreach ($entry in $uTables) {
			Invoke-SQLScript $entry
		}
	}
	if ($uTableAlter.Count -gt 0) {
		Write-Output "Running alter table scripts"
		foreach ($entry in $uTableAlter) {
			Invoke-SQLScript $entry
		}
	}
	if ($uViews.Count -gt 0) {
		Write-Output "Running view scripts"
		foreach ($entry in $uViews) {
			Invoke-SQLScript $entry
		}
	}
	if ($uFunctions.Count -gt 0) {
		Write-Output "Running function scripts"
		foreach ($entry in $uFunctions) {
			Invoke-SQLScript $entry
		}
	}
	if ($uStoredProcedures.Count -gt 0) {
		Write-Output "Running stored procedure scripts"
		foreach ($entry in $uStoredProcedures) {
			Invoke-SQLScript $entry
		}
	}
	if ($uScripts.Count -gt 0) {
		Write-Output "Running script scripts"
		foreach ($entry in $uScripts) {
			Invoke-SQLScript $entry
		}
	}
	if ($uIndexes.Count -gt 0) {
		Write-Output "Running index scripts"
		foreach ($entry in $uIndexes) {
			Invoke-SQLScript $entry
		}
	}
	if ($uOther.Count -gt 0) {
		Write-Output "Running other scripts"
		foreach ($entry in $uOther) {
			Invoke-SQLScript $entry
		}
	}
	if ($specialScriptList.Count -gt 0) {
		Write-Output "NOTIFY DBA OF FOLLOWING SCRIPTS:"
		Send-MailMessage -To "richard.hopkins@equator.com; sintayow.bekele@equator.com" -From "eqDevOps@equator.com" -Subject "SPECIAL SCRIPTS NEED ATTENTION" -Body "Pay attention to the last SQL deployment" -SmtpServer "smtp-dev"
		foreach ($entry in $specialScriptList) {
			Write-Output "THIS IS A SPECIAL SCRIPT"
			Write-Output $entry
		}
	}
} else {
	Write-Output "No scripts to run."
}