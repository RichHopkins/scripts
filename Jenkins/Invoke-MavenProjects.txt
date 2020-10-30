[CmdletBinding()]
param
(
	[Parameter(Mandatory = $true)]
	[ValidateSet('Development', 'DevInt', 'AlphaX7', 'Alpha', IgnoreCase = $False)]
	[string]$environment
)

Import-Module eqDevOps

function Send-DevNotification {
	param
	(
		[string]$strProject,
		$devs,
		[string[]]$attach
	)
	$developers = ""
	ForEach ($dev in $devs) { $developers += "$($dev.Developer)@equator.com, " }
	$developers = $developers.TrimEnd(", ")
	Write-ToSlack -Channel "`#devops-$environment" -Message "Emailing the following developers about the failure of $strProject - $developers"
	$subject = "$($environment.ToUpper()) MAVEN FAILURE FOR $strProject"
	$body = "There was an error when running the Maven Project <b><font color=red>$strProject</b></font><BR> that you recently worked on."
	$body += "Please see the attached log file for details.<BR><BR>"
	$body += "Contact DevOps for any assistance.<BR><BR>"
	$body += "Equator DevOps Team<BR>"
	$body += "eqdevops@equator.com<BR><BR>"
	Send-MailMessage -SmtpServer "smtp-dev" -To $($developers -split ", ") -Cc "_COE.EntArch.DevOps@equator.com" -From "_COE.EntArch.DevOps@equator.com" -Subject $subject -Body $body -BodyAsHtml -Attachments $attach
}

function Create-SMProject ($strCPID, $strFileName, $strDeveloper, $strProject) {
	$temp = New-Object System.Object
	$temp | Add-Member -MemberType NoteProperty -Name "CPID" -Value "$strCPID"
	$temp | Add-Member -MemberType NoteProperty -Name "FileName" -Value "$strFileName"
	$temp | Add-Member -MemberType NoteProperty -Name "Developer" -Value "$strDeveloper"
	$temp | Add-Member -MemberType NoteProperty -Name "Project" -Value "$strProject"
	return $temp
}

function Get-ProjectInfo {
	param ($cpid)
	$CPIDInsertFile = Join-Path -Path $CPFolder -ChildPath "$($cpid.Replace(":", "_")).txt"
	$GetCPDetails = si.exe viewcp --yes --user=$IntegrityUser --password=$IntegrityPass --format="{revision},{variant},{member},{project},{user},{id}\n" --headerformat="" $cpid
	$returnData = @()
	foreach ($CPContent in $GetCPDetails) {
		$a = $CPContent -split ","
		$FileName = ($a[2])
		$FileProject = ($a[3])
		$FileDev = ($a[4])
		$FileDev = $FileDev -split " "
		$developer = $FileDev[2] -replace '[()]', ''
		$FileID = ($a[5]).Replace(":", "_")
		$FileProject = $FileProject -split "/"
		if ($FileProject[2] -eq "project") { $sProject = $FileProject[3] }
		else {$sProject = "none"}
		$returnData += Create-SMProject -strCPID $FileID -strFileName $FileName -strDeveloper $developer -strProject $sProject
	}
	return $returnData
}

#Script Start
$configData = Get-XMLFile "\\DevOps\Config\EQConfig.xml"
$JenkinsData = $configData.Configuration.JenkinsData
$envPath = Join-Path -Path $JenkinsData.WorkflowPaths.Builds -ChildPath $environment
$IntegrityUser = $JenkinsData.IntegrityData.IntegrityUser
$IntegrityPass = $JenkinsData.IntegrityData.IntegrityPass
$projectPath = Join-Path -Path $JenkinsData.WorkflowPaths.Environments -ChildPath "$environment\servicemart"
$javaBuildPath = Join-Path -Path $envPath -ChildPath "\Java"
$logPath = Join-Path -Path $envPath -ChildPath "\Logs\Java"
$CPFolder = Join-Path -Path $logPath -ChildPath "\CPs"

If (Test-Path -Path $projectPath) {
	Connect-Integrity -username $IntegrityUser -password $IntegrityPass

	switch ($environment) {
		"DevInt" { $IntegrityEnvironment = "Development" }
		"AlphaX7" { $IntegrityEnvironment = "AlphaX" }
		"Alpha" { $IntegrityEnvironment = "Dev Int" }
	}

	foreach ($i in Get-Content "$envPath\thisBuildTime.txt") {
		$script:dtThisBuild = $i
	}
	foreach ($i in Get-Content "$envPath\lastBuildTime.txt") {
		$script:dtLastBuild = $i
	}

	$strQueryDef = "((field[Environment] = $IntegrityEnvironment) and (genericcp:si:attribute[closeddate] between time $dtLastBuild and $dtThisBuild) and (field[Type] = Back Promote Task,Propagation Task) and (field[Configuration Project] = servicemart))"
	im.exe editquery --yes --user=$IntegrityUser --password=$IntegrityPass --queryDefinition="$strQueryDef" "$IntegrityEnvironment SM commits"
	Write-Output "Updated MKS CP Query."
	$CPIDS = si.exe viewcps --yes --user=$IntegrityUser --password=$IntegrityPass --query="$IntegrityEnvironment SM commits" --fields=ID
	Write-Output "Execute MKS CP Query."

	$ProjectData = @()
	ForEach ($cpid in $CPIDS) {
		$CPIDString = $cpid.Replace(":", "_")
		$CPIDFile = Join-Path -Path $CPFolder -ChildPath "\$CPIDString.txt"
		Write-Output "Processing CP $CPIDString"
		if (!(Test-Path $CPIDFile)) {
			New-Item -Path $CPIDFile -ItemType file -Value "Getting info for CP $cpid" -Force
			Write-Output "Getting info for CP $cpid"
			$ProjectInfo = Get-ProjectInfo -cpid $cpid
			$ProjectData += $ProjectInfo
			Out-File -FilePath $CPIDFile -InputObject $ProjectInfo -Encoding UTF8 -Append
		}
		else { Write-Output "Skipping files for CP $CPIDFile" }
	}

	$ProjectList = $ProjectData | Select-Object -Unique -Property "Project" | Where-Object { $_.Project -ne "none" }
	If ($ProjectList) {
		ForEach ($Project in $ProjectList) {
			$projectPomPath = Join-Path -Path $projectPath -ChildPath "$($Project.Project)\pom.xml"
			$projectPomData = Get-XMLFile -xmlFile $projectPomPath
			$projectName = $projectPomData.project.artifactId.ToString()
			If ($projectPomData.project.parent.artifactId.ToString() -eq "SMMavenParent") {
				Invoke-Maven -goal clean -pomPath $projectPomPath
				Invoke-Maven -goal install -pomPath $projectPomPath | Tee-Object -FilePath "$logPath\$projectName_install.log"
				Invoke-Maven -goal deploy -pomPath $projectPomPath -deployPath $javaBuildPath | Tee-Object -FilePath "$logPath\$projectName_deploy.log"
				$isInstallError = Get-Content "$logPath\$projectName_install.log" | Where-Object { $_ -match "BUILD FAILURE" }
				$isDeployError = Get-Content "$logPath\$projectName_install.log" | Where-Object { $_ -match "BUILD FAILURE" }
				If ($isInstallError -or $isDeployError) {
					$devs = $ProjectData | Where-Object { $_.Project -eq $projectName } | Select-Object -Unique -Property "Developer"
					Send-DevNotification -project $projectName -devs $devs -attach "$logPath\$projectName_install.log", "$logPath\$projectName_deploy.log"
				}
			}
			else {
				$parentProject = $projectPomData.project.parent.artifactId.ToString()
				$parentPomPath = Join-Path -Path $projectPath -ChildPath "$parentProject\pom.xml"
				$parentPomData = Get-XMLFile -xmlFile $parentPomPath
				foreach ($module in $parentPomData.project.modules) {
					If ($module -eq "../$projectName") { $boolBuildParent = $true }
				}
				If ($boolBuildParent) {
					$parentProjectName = $parentPomData.project.artifactId.ToString()
					Invoke-Maven -goal clean -pomPath $parentPomPath
					Invoke-Maven -goal install -pomPath $parentPomPath | Tee-Object -FilePath "$logPath\$parentProjectName_install.log"
					Invoke-Maven -goal deploy -pomPath $parentPomPath -deployPath $javaBuildPath | Tee-Object -FilePath "$logPath\$parentProjectName_deploy.log"
					$isInstallError = Get-Content "$logPath\$parentProjectName_install.log" | Where-Object { $_ -match "BUILD FAILURE" }
					$isDeployError = Get-Content "$logPath\$parentProjectName_deploy.log" | Where-Object { $_ -match "BUILD FAILURE" }
					If ($isInstallError -or $isDeployError) {
						$devs = $ProjectData | Where-Object { $_.Project -eq $projectName } | Select-Object -Unique -Property "Developer"
						Send-DevNotification -project $projectName -devs $devs -attach "$logPath\$parentProjectName_install.log", "$logPath\$parentProjectName_deploy.log"
					}
				}
				else {
					Invoke-Maven -goal clean -pomPath $projectPomPath
					Invoke-Maven -goal install -pomPath $projectPomPath | Tee-Object -FilePath "$logPath\$projectName_install.log"
					Invoke-Maven -goal deploy -pomPath $projectPomPath -deployPath $javaBuildPath | Tee-Object -FilePath "$logPath\$projectName_deploy.log"
					$isInstallError = Get-Content "$logPath\$projectName_install.log" | Where-Object { $_ -match "BUILD FAILURE" }
					$isDeployError = Get-Content "$logPath\$projectName_install.log" | Where-Object { $_ -match "BUILD FAILURE" }
					If ($isInstallError -or $isDeployError) {
						$devs = $ProjectData | Where-Object { $_.Project -eq $projectName } | Select-Object -Unique -Property "Developer"
						Send-DevNotification -project $projectName -devs $devs -attach "$logPath\$projectName_install.log", "$logPath\$projectName_deploy.log"
					}
				}
			}
		}
	}
	else {
		Write-Output "No projects need updating."
	}

	Disconnect-Integrity -username $IntegrityUser -password $IntegrityPass
	Exit-Integrity
}