#region ScriptFuntions
function Measure-DiskSpace {
	[CmdletBinding()]
	[OutputType([psobject])]
	param
	(
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName
	)
	
	Try {
		$disks = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID = 'C:'" -ComputerName $ComputerName -ErrorAction Stop
		foreach ($disk in $disks) {
			[float]$size = $disk.Size
			[float]$freespace = $disk.FreeSpace
			[psobject]$returnObj = New-Object -Property @{
				DeviceID = $disk.DeviceID;
				VolumeName = $disk.VolumeName;
				Size = [float]$disk.Size;
				FreeSpace = [float]$disk.FreeSpace;
				percentFree = [Math]::Round(($freespace / $size) * 100, 2);
				sizeGB = [Math]::Round($size / 1073741824, 2);
				freeSpaceGB = [Math]::Round($freespace / 1073741824, 2);
				usedSpaceGB = $sizeGB - $freeSpaceGB;
			} -TypeName psobject
		}
		
		return $returnObj
	} Catch {
		Write-Error "Unable to connect to WMI for $ComputerName "
	}
}

function Invoke-VDICleanup {
	[CmdletBinding()]
	param
	(
		[Parameter(Position = 0)]
		[string]$ComputerName = $env:COMPUTERNAME,
		[Parameter(Position = 1)]
		[string[]]$userID = @($env:USERNAME),
		[Parameter(Position = 2)]
		[switch]$Aggressive
	)
	
	Try {
		$session = New-PSSession -ComputerName $ComputerName
		
		#Remove profiles that haven't been used in 30 days.
		Invoke-Command -Session $session -ScriptBlock {
			$ProfileInfo = Get-WmiObject -Class Win32_UserProfile | Where-Object {
				$_.ConvertToDateTime($_.LastUseTime) -le (Get-Date).AddDays(-30) -and $_.LocalPath -notlike "*$env:SystemRoot*" #-and $_.LocalPath -notlike "*$userID*"
			}
			Foreach ($Profile in $ProfileInfo) {
				Try {
					$Profile.Delete()
					Write-Output "Delete profile '$($Profile.LocalPath)' successfully."
				} Catch {
					Write-Error "Delete profile '$($Profile.LocalPath)' failed."
				}
			}
		}
		
		#Empty recycle bin
		Invoke-Command -Session $session -ScriptBlock {
			$Shell = New-Object -ComObject Shell.Application
			$RecBin = $Shell.Namespace(0xA)
			$RecBin.Items() | ForEach-Object{
				Remove-Item $_.Path -Recurse -Confirm:$false
			}
		}
		
		#Cleaning Windows Update Service
		Invoke-Command -Session $session -ScriptBlock {
			Stop-Service wuauserv -Force
			Remove-Item -Path "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force
			Start-Service wuauserv
		}
		
		#Clean up various temp folders and other unneeded data
		[string[]]$arrPathsToClean = @(
			"C:\Windows\Temp\*",
			"C:\Users\Public\Downloads\*",
			"C:\Users\*\AppData\LocalLow\Temp\*",
			"C:\Users\*\AppData\LocalLow\Adobe\Acrobat\9.0\Search\*",
			"C:\Users\*\AppData\Local\Temp\*",
			"C:\Users\*\AppData\Local\Google\Chrome\User Data\Default\Cache\*",
			"C:\Users\*\AppData\Local\Citrix\GoToMeeting\*",
			"C:\Users\*\AppData\Local\Microsoft\Windows\Temporary Internet Files\*",
			"C:\Users\*\AppData\Local\Microsoft\Windows\WER\ReportArchive\*",
			"C:\Users\*\AppData\Roaming\Mozilla\Firefox\Crash Reports\pending\*"
		)
		Invoke-Command -Session $session -ScriptBlock {
			Get-ChildItem -Path $arrPathsToClean -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -ErrorAction SilentlyContinue -Recurse
		} -ArgumentList $arrPathsToClean
		
		#Clear old lync bak files
		Invoke-Command -Session $session -ScriptBlock {
			Get-ChildItem -Path "C:\Users\*\AppData\Local\Microsoft\Office\15.0\Lync\Tracing" -Filter *.bak -Force -ErrorAction SilentlyContinue | Remove-Item -ErrorAction SilentlyContinue
		}
		
		#Clear old GoToMeeting versions
		Invoke-Command -Session $session -ScriptBlock {
			If (Test-Path "C:\Program Files (x86)\Citrix\GoToMeeting") {
				Push-Location "C:\Program Files (x86)\Citrix\GoToMeeting"
				$go2dirs = Get-ChildItem "C:\Program Files (x86)\Citrix\GoToMeeting" | Where-Object {
					$_.PSIsContainer
				}
				$go2dirs = $go2dirs | Sort-Object CreationTime -Descending | Select-Object * -Skip 1
				$go2dirs | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
			}
		}
		
		#Clear old Chrome versions and current installer
		Invoke-Command -Session $session -ScriptBlock {
			If (Test-Path "C:\Program Files (x86)\Google\Chrome\Application") {
				Push-Location "C:\Program Files (x86)\Google\Chrome\Application"
				$chromeDirs = Get-ChildItem "C:\Program Files (x86)\Google\Chrome\Application" | Where-Object {
					$_ -match "\d{2}\." -and $_.PSIsContainer
				}
				#Gets collection of chromes directories, but skips the most recent version (don't want to delete that)
				$chromeDirs = $chromeDirs | Sort-Object CreationTime -Descending | Select-Object * -Skip 1
				$chromeDirs | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
				#Cleans the installer directory from the current version
				$chromeDirs = Get-ChildItem "C:\Program Files (x86)\Google\Chrome\Application" | Where-Object {
					$_ -match "\d{2}\." -and $_.PSIsContainer
				}
				Remove-Item -Path "$chromeDirs\Installer" -Force -Recurse -ErrorAction SilentlyContinue
				Pop-Location
			}
		}
		#Clear CBS files
		Invoke-Command -Session $session -ScriptBlock {
			$cbsDirs = Get-ChildItem "C:\Windows\Logs\CBS\*" -Recurse -Force
			$cbsDirs | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
		}
		
		#If drive space is critical, get aggressive in trying to clean up space
		If ($Aggressive) {
			#Clean up the PageFile
			Invoke-Command -Session $session -ScriptBlock {
				Function Set-PageFileSize {
					Param ($DriveLetter,
						$InitialSize,
						$MaximumSize)
					#The AutomaticManagedPagefile property determines whether the system managed pagefile is enabled. 
					#Only if it is NOT managed by the system and will also allow you to change these.
					$IsAutomaticManagedPagefile = Get-WmiObject -Class Win32_ComputerSystem | Foreach-Object{
						$_.AutomaticManagedPagefile
					}
					If ($IsAutomaticManagedPagefile) {
						#We must enable all the privileges of the current user before the command makes the WMI call.
						$SystemInfo = Get-WmiObject -Class Win32_ComputerSystem -EnableAllPrivileges
						$SystemInfo.AutomaticManagedPageFile = $false
						[Void]$SystemInfo.Put()
					}
					Write-Verbose "Setting pagefile on $DriveLetter"
					#configuring the page file size
					$PageFile = Get-WmiObject -Class Win32_PageFileSetting -Filter "SettingID='pagefile.sys @ $DriveLetter'"
					Try {
						#Delete page file
						If ($PageFile -ne $null) {
							$PageFile.Delete()
						}
						Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{
							Name = "$DriveLetter\pagefile.sys"; InitialSize = 0; MaximumSize = 0
						} -EnableAllPrivileges | Out-Null
						$PageFile.InitialSize = $InitialSize
						$PageFile.MaximumSize = $MaximumSize
						[Void]$PageFile.Put()
						Write-Output  "Execution Results: Set page file size on ""$DriveLetter"" successful."
						Write-Warning "Pagefile configuration changed on computer '$Env:COMPUTERNAME'. The computer must be restarted for the changes to take effect."
					} Catch {
						Write-Error "Execution Results: No Permission - Failed to set page file size on ""$DriveLetter"""
					}
				}
				#Get ammount of RAM assigned to system
				[int]$MemMB = (Get-WmiObject -class "Win32_PhysicalMemoryArray").MaxCapacity /1kb
				Set-PageFileSize -DriveLetter C -InitialSize $MemMB/4 -MaximumSize $MemMB/2
			} #end Invoke PageFile clean up
			
			#Run cleanup tool
			Invoke-Command -Session $session -ScriptBlock {
				Write-Output 'Clearing CleanMgr.exe automation settings.'
				Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\*' -Name StateFlags0001 -ErrorAction SilentlyContinue | Remove-ItemProperty -Name StateFlags0001 -ErrorAction SilentlyContinue
				Write-Output 'Enabling Update Cleanup. This is done automatically in Windows 10 via a scheduled task.'
				New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Update Cleanup' -Name StateFlags0001 -Value 2 -PropertyType DWord
				Write-Output 'Enabling Temporary Files Cleanup.'
				New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Temporary Files' -Name StateFlags0001 -Value 2 -PropertyType DWord
				Write-Output 'Starting CleanMgr.exe...'
				Start-Process -FilePath CleanMgr.exe -ArgumentList '/sagerun:1' -WindowStyle Hidden -Wait
				#Second wait neccesary as CleanMgr.exe spins off separate processes.
				Write-Output 'Waiting for CleanMgr and DismHost processes to complete.'
				Get-Process -Name cleanmgr, dismhost -ErrorAction SilentlyContinue | Wait-Process
				$UpdateCleanupSuccessful = $false
				if (Test-Path $env:SystemRoot\Logs\CBS\DeepClean.log) {
					$UpdateCleanupSuccessful = Select-String -Path $env:SystemRoot\Logs\CBS\DeepClean.log -Pattern 'Total size of superseded packages:' -Quiet
					Write-Output 'CleanMgr.exe run was a success'
				} else {
					Write-Output 'CleanMgr.exe run failed'
				}
			}
			
			#Reboot critical system and wait for it to come back online
			Restart-Computer -ComputerName $ComputerName -Force
			Start-Sleep -Seconds 30
			Do {
				$session = New-PSSession -ComputerName $ComputerName -ErrorAction SilentlyContinue
			} Until ($session)
		} #end Aggressive
	} Catch {
		Write-Error "Unable to connect to $ComputerName! "
	}
}


#endregion ScriptFuntions

#############################################################################
#                                                                           #
#  Check disk space and send an HTML report as the body of an email.        #
#  Reports only disks on computers that have low disk space.                #
#  Author: Mike Carmody                                                     #
#  Some ideas extracted from Thiyagu's Exchange DiskspaceHTMLReport module. #
#  Date: 8/10/2011                                                          #
#  I have not added any error checking into this script yet.                #
#  Addendums: Fortch                                                        #
#  UPDATED: 2/21/17 by Rich Hopkins                                         #
#                                                                           #
#############################################################################

#########################################################################################
# Items to change to make it work for you.
#
# EMAIL PROPERTIES
#  - the $users that this report will be sent to.
#  - near the end of the script the smtpserver, From and Subject.
#
# REPORT PROPERTIES
#  - you can edit the report path and report name of the html file that is the report. 
#########################################################################################

# Query AD and produce computer list
Import-Module ActiveDirectory
Get-ADComputer -Filter {
	OperatingSystem -Like "*Windows*" -and Description -Like "*hopkins*"
} -Properties Description | Select-Object Name, Description | ConvertTo-Csv -NoTypeInformation | Out-File C:\VDIWorkStations.csv

# Set your warning and critical thresholds
$percentWarning = 10
$percentCritcal = 5

# EMAIL PROPERTIES
# Set the recipients of the report.
#$users = "You@company.com" # I use this for testing by uing my email address.
$users = "richard.hopkins@equator.com"
#$users = "_it.noc.team@equator.com", "helpdesk@equator.com", "mark.payne@equator.com"  # can be sent to individuals.


# REPORT PROPERTIES
# Path to the report
$reportPath = "C:\"

# Report name
$reportName = "DiskSpaceRpt_$(get-date -format ddMMyyyy).html"

# Path and Report name together
$diskHTMLReport = $reportPath + $reportName

#Set colors for table cell backgrounds
$redColor = "#FF0000"
$orangeColor = "#FBB917"
$whiteColor = "#FFFFFF"

# Count if any computers have low disk space.  Do not send report if less than 1.
$intComputerCount = 0

# Get computer list to check disk space
$computers = Import-Csv "C:\VDIWorkStations.csv"
$datetime = Get-Date -Format "ddMMyyyy"

# Remove the report if it has already been run today so it does not append to the existing report
If (Test-Path $diskHTMLReport) {
	Remove-Item $diskHTMLReport
}

# Cleanup old files..
$Daysback = "-30"
$CurrentDate = Get-Date
$DateToDelete = $CurrentDate.AddDays($Daysback)
Get-ChildItem "$reportPath\*.html" | Where-Object {
	$_.LastWriteTime -lt $DatetoDelete
} | Remove-Item

# Create and write HTML Header of report
$titleDate = get-date -uformat "%m-%d-%Y - %A"
$header = "
		<html>
		<head>
		<meta http-equiv='Content-Type' content='text/html; charset=iso-8859-1'>
		<title>DiskSpace Report</title>
		<STYLE TYPE='text/css'>
		<!--
		td {
			font-family: Tahoma;
			font-size: 11px;
			border-top: 1px solid #999999;
			border-right: 1px solid #999999;
			border-bottom: 1px solid #999999;
			border-left: 1px solid #999999;
			padding-top: 0px;
			padding-right: 0px;
			padding-bottom: 0px;
			padding-left: 0px;
		}
		body {
			margin-left: 5px;
			margin-top: 5px;
			margin-right: 0px;
			margin-bottom: 10px;
			table {
			border: thin solid #000000;
		}
		-->
		</style>
		</head>
		<body>
		<table width='100%'>
		<tr bgcolor='#CCCCCC'>
		<td colspan='7' height='25' align='center'>
		<font face='tahoma' color='#003399' size='3'><strong>HQ Environment DiskSpace Report for $titledate</strong></font>
		</td>
		</tr>
		</table>
"
Add-Content $diskHTMLReport $header

# Create and write Table header for report
$tableHeader = "
	<table width='100%'><tbody>
	<tr bgcolor=#CCCCCC>
	<td width='10%' align='center'>Server</td>
	<td width='5%' align='center'>Drive</td>
	<td width='15%' align='center'>Drive Label</td>
	<td width='10%' align='center'>Total Capacity(GB)</td>
	<td width='10%' align='center'>Used Capacity(GB)</td>
	<td width='10%' align='center'>Free Space(GB)</td>
	<td width='5%' align='center'>Freespace %</td>
	</tr>
"
Add-Content $diskHTMLReport $tableHeader

# Start processing disk space reports against a list of servers
foreach ($computer in $computers) {
	$ComputerName = $computer.Name
	$owner = $computer.Description
	$ComputerName = $ComputerName.ToUpper()
	$diskData = Measure-DiskSpace -computerName $ComputerName -ErrorAction Continue
	$bgColor = $whiteColor
	
	# If low, attempt cleanup and rescan
	if ($diskData.percentFree -lt $percentCritcal) {
		Invoke-VDICleanup -ComputerName $ComputerName -userID $owner -Aggressive
		$diskData = Measure-DiskSpace -computerName $ComputerName
	} elseif ($diskData.percentFree -lt $percentWarning) {
		Invoke-VDICleanup -ComputerName $ComputerName -userID $owner
		$diskData = Measure-DiskSpace -computerName $ComputerName
	}
	
	# If still low, set background color to Orange if just a warning
	if ($diskData.percentFree -lt $diskData.percentWarning) {
		$bgColor = $orangeColor
		
		# Set background color to Red if space is Critical
		if ($diskData.percentFree -lt $diskData.percentCritcal) {
			$bgColor = $redColor
		}
		
		# Create table data rows 
		$dataRow = "
		<tr>
		<td width='10%'>$ComputerName</td>
		<td width='5%' align='center'>$deviceID</td>
		<td width='15%' >$volName</td>
		<td width='10%' align='center'>$sizeGB</td>
		<td width='10%' align='center'>$usedSpaceGB</td>
		<td width='10%' align='center'>$freeSpaceGB</td>
		<td width='5%' bgcolor=`'$bgColor`' align='center'>$percentFree</td>
		</tr>
"
		Add-Content $diskHTMLReport $dataRow
		Write-Output "$ComputerName $deviceID percentage free space = $percentFree"
		$intComputerCount++
	}
	
}

# Create table at end of report showing legend of colors for the critical and warning
$tableDescription = "
	</table><br><table width='20%'>
	<tr bgcolor='White'>
	<td width='10%' align='center' bgcolor='#FBB917'>Warning less than $percentWarning% free space</td>
	<td width='10%' align='center' bgcolor='#FF0000'>Critical less than $percentCritcal% free space</td>
	</tr>
"
Add-Content $diskHTMLReport $tableDescription
Add-Content $diskHTMLReport "</body></html>"

# Send Notification if alert $i is greater then 0
if ($intComputerCount -gt 0) {
	foreach ($user in $users) {
		Write-Output "Sending Email notification to $user"
		
		$smtpServer = "smtp.rtllc.local"
		$smtp = New-Object Net.Mail.SmtpClient($smtpServer)
		$msg = New-Object Net.Mail.MailMessage
		$msg.To.Add($user)
		$msg.From = "it.inf.systems@equator.com"
		$msg.Subject = "VDI DiskSpace Report for $titledate"
		$msg.IsBodyHTML = $true
		$msg.Body = get-content $diskHTMLReport
		$smtp.Send($msg)
		$body = ""
	}
}