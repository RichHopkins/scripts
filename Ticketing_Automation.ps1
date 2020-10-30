#Load the Outlook Assembly
Add-type -AssemblyName "Microsoft.Office.Interop.Outlook" | out-null
#who to notify on success and errors
$notifyEmail = 'eqDevOps@equator.com', 'sellerhelp@equator.com'
#only create tickets from the following users
$allowedList = @('Hopkins, Richard A', 'EQBusiness_Support@fanniemae.com', 'Lynna_M_Theimer@fanniemae.com', 'Jordan_Velasco@fanniemae.com', 'richard_plotnick@fanniemae.com', 'michelle_arend@fanniemae.com', 'michelle_d_valitutto@fanniemae.com')
#setup other script variables
$smtp = "smtp-dev.rtllc.local"
$hostname = 'integrity'
$time = Get-Date -format "dd-MMM-yyyy HH:mm"
$date = Get-Date -format "dd-MMM-yyyy"
$logDir = "c:\scripts\Logs\$date\"
$logFile = "$logDir\LogFile.txt"
$IsThereAttachment = $false
$priority = 'Low'
$ClientSeverity = 4
$Severity = 4
#create the log path
if (!(Test-Path $logDir)) {
	mkdir $logDir -Force
}
"Started at - $time" >> "$logDir\Scheduler.log"
"Step 1 - $time" > "$logDir\CurrentProcess.log"
#kill any running integrity processes, as leaving it open makes the machine prone to memory errors
Stop-Process -Name integrity* -force
#instead of passing the password here, cache it into the MKS client properties
im connect --hostname=$hostname --port=7001 --yes #--user=SVC-MKS.Import --password=*:$`'cg7JvX+zP,E
"Step 2 - $time" >> "$logDir\CurrentProcess.log"
#object for browsing folders in Outlook
$olFolders = "Microsoft.Office.Interop.Outlook.olDefaultFolders" -as [type]
#object for saving email messages as a local msg file type
$olSaveType = "Microsoft.Office.Interop.Outlook.OlSaveAsType" -as [type]
#setup Outlook COM object
$outlook = New-Object -comobject outlook.application
#connect to MAPI namespace
$namespace = $outlook.GetNameSpace("MAPI")
#get details of the root folder in Outllok
$folder = $namespace.getDefaultFolder($olFolders::olFolderInBox)
"Step 3 - Loaded outlook objects - $time"  >> "$logDir\CurrentProcess.log"
#loop through each email in root folder and process them
foreach ($email in $folder.items) {
	"$time - " + $email.subject >> "$logDir\All_Emails.txt"
	#only process unread messages
	if ($email.unread -eq 'True') {
		$subject = $email.subject
		$body = $email.body
		$Senderemail = $email.Senderemail
		"Step 4 - Looping over emails - $time"  >> "$logDir\CurrentProcess.log"
		#Process email if following conditions are met
		##Sendername or SenderEmailAddress must be members of $allowedList
		##email subject is not a FW:, RE:, or Recall
		##the entry in the allowed list must be in the body of the message
		##and another check to make sure the subject isn't FW: or RE:
		if ((($allowedList -contains $email.Sendername -or $allowedList -contains $email.SenderEmailAddress) -and !($email.subject -like 'FW:*' -or $email.subject -like 'RE:*' -or $email.subject -like 'Recall*')) -or ($email.Sendername.contains('eq_') -and $email.subject -like 'FW:*' -and ($allowedList | ForEach-Object {
						($body -contains $_)
					} | Select-String -Pattern 'True' | Get-Unique) -and !($email.subject.contains('RE:')))) {
			#check to see if the email subject is already listed in Unread_Emails.txt
			$validateSubject = Select-String -Path "$logDir\Unread_Emails.txt" -SimpleMatch $email.subject
			#if found, treat email as duplicate
			if ($validateSubject) {
				$emailBody = "Automation Script skipped Ticket creation for email subject <br/><br/> $subject <br/><br/>"
				$EmailSubject = "Duplicate Email - $subject"
				Send-MailMessage -to $notifyEmail -From 'support@mks.com' -Body $emailBody -SmtpServer $smtp -Subject $EmailSubject -BodyAsHtml
				"$time - $emailBody" >> "$logDir\Duplicate_Emails.txt"
				$email.UnRead = $false
			} Else {
				#After passing all above checks, treat the email as one to create a ticket for
				$email.UnRead = $false
				#log email in Unread_Emails.txt
				"$time - $Senderemail - $subject" >> "$logDir\Unread_Emails.txt"
				$senton = $email.senton
				#Email subjects follow this pattern:
				## INC000987654321 | EQ Sev 3 | Field Services | Inbound WorkOrder_Service Field Name: work_order_services
				if ($Subject.contains('|') -and (((($Subject.split('|') | Measure-Object)).count) -eq 4)) {
					$ClientTicketID = $Subject.split("|")[0]
					$Severity = $Subject.split("|")[1]
					if (!(($ClientTicketID | Measure-Object -Character).Characters -eq 15)) {
						$ClientTicketID = 'INC N/A'
					}
				} Else {
					#if subject doesn't follow patern, use default values
					$ClientTicketID = 'INC N/A'
					$Severity = '4'
				}
				if (!($ClientTicketID.Contains("INC"))) {
					$ClientTicketID = ''
				}
				#set ticket priority
				if ($Severity.trim.length) {
					if ($Severity.contains(1)) {
						$ClientSeverity = 1; $priority = 'Critical'
					} ElseIf ($Severity.contains(2)) {
						$ClientSeverity = 2; $priority = 'Critical'
					} ElseIf ($Severity.contains(3)) {
						$ClientSeverity = 3; $priority = 'High'
					} ElseIF ($Severity.contains(4)) {
						$ClientSeverity = 4; $priority = 'Medium'
					} Else {
						$ClientSeverity = 4; $priority = 'Low'
					}
				}
				#remove all forms of a single and double quote from the subject and body
				$subject = $subject.Replace('"', '').Replace('""', '').Replace('‘', '').Replace('’', '').Replace('“', '').Replace('”', '')
				$body = $body.Replace('"', '').Replace('""', '').Replace('‘', '').Replace('’', '').Replace('“', '').Replace('”', '')
				$body > c:\scripts\body.txt
				#write the body to a file then select the first 100 characters (thats the limit on MKS ticket subjects)
				$description = Get-Content c:\scripts\body.txt | Select-Object -first 100
				#remove any characters from the body that MKS choaks on
				$description = $description -replace '\$|\(|\)|\*|\+|\.|\[|\]|\?|\\|\/|\^|\{|\}|\||\"|\"|\-|\"|', ''
				#clean up the description
				if ($description.Contains("""")) {
					$description = $description.Replace('"', '').Replace('""', '').Replace('"', '').Replace('"', '')
				}
				#finally create the issue and pipe the output to test.txt
				im createissue --hostname=$hostname --port=7001 --type='Incident Ticket' `
				   --field="Summary=$subject" `
				   --field="Description=$description" `
				   --field="comments=Incident Ticket created using Automation Script." 2>&1 > c:\scripts\test.txt
				#get the ticket number
				$TicketID = get-content c:\scripts\test.txt | select-string -pattern "Created Incident Ticket"
				$TicketID = $TicketID -replace 'Created Incident Ticket ', ''
				#check for any file attachments in the email
				foreach ($item in $email.attachments) {
					if ($item.filename) {
						$IsThereAttachment = $true
					}
				}
				#create a folder for the issue
				$FileDir = "c:\scripts\temp\$TicketID"
				mkdir $fileDir -force
				$TicketID
				#initial ticket is created with only a Summary and Description, now we edit the issue with needed properties
				if ($TicketID) {
					"Updating the ticket $TicketID to Servicer Support Queue" >> c:\scripts\test.log
					$dest = "$FileDir\email.msg"
					#save email to a msg file to be added as an attachment
					$email.SaveAs($dest, $olSaveType::olMSG)
					im editissue --hostname=$hostname --port=7001 `
					   --field="Person ID=113" `
					   --field="State=Initial Classification" `
					   --field="Assigned User=Servicer Support Queue" `
					   --field="priority=$priority" `
					   --field="Contact Type=Lender" `
					   --field="Client=Fannie Mae" `
					   --field="Module=Real Estate Owned (REO)" `
					   --field="Client Severity=$ClientSeverity" `
					   --field="Subclient=_Fannie Mae" `
					   --field="Incident origin=Email" `
					   --field="Incident Type=Technical Incident" `
					   --field="Incident Category=Exceptions" `
					   --field="Incident Subcategory=Application Exceptions" `
					   --field="Email Received=$senton" `
					   --field="Client Ticket ID=$ClientTicketID" `
					   --field="contact=EQBusiness_Support@fanniemae.com - FM Business Support"  `
					   --field="Client Functional Area=Integration" `
					   --addAttachment="field=Attachments,path=$dest,name=email.msg" $TicketID
					#add any file attachments from the email to the issue
					if ($IsThereAttachment) {
						$email.attachments | ForEach-Object {
							$a = $_.filename
							$filePath = Join-Path $FileDir $a
							$_.saveasfile(($filePath))
							im editissue --hostname=$hostname --port=7001 --addAttachment="field=Attachments,path=$filePath,name=$a" $TicketID  2>&1 > c:\scripts\MiscLog.log
						}
					}
				}
				"Step 5-Ticket Created - $time"  >> "$logDir\CurrentProcess.log"
				"Updating the ticket $TicketID to Remediation Queue" >> c:\scripts\test.log
				#if a ticket number wasn't generated email the details to the $notifyEmail list
				if (!($TicketID)) {
					'Failed to Create MKS Ticket' + $subject
					$TicketID = 'FAILED - ' + $subject
					"$time - $TicketID" >> "$logDir\ErrorLog.log"
					get-content c:\scripts\test.txt >> "$logDir\ErrorLog.log"
					$command = @"
im createissue --hostname=$hostname --port=7001 --type='Incident Ticket' --field="Summary=$subject" --field="Description=$description" --field="comments=Incident Ticket created using Automation Script."
"@
					"The following command failed:" >> "$logDir\ErrorLog.log"
					$command >> "$logDir\ErrorLog.log"
					$EmailSubject = $TicketID
				} Else {
					im viewissue --hostname=$hostname --port=7001 $TicketID  > c:\scripts\IncDtls.txt
					$AssignedUser = get-content c:\scripts\IncDtls.txt | select-string -pattern "Assigned User:"
					$AssignedUser = $AssignedUser -replace 'Assigned User:', ''
				}
				"Email will be sent to User : $notifyEmail"
				$emailBody = "$subject<br/>$TicketID"
				$EmailSubject = "$TicketID - $subject"
				"$TicketID - $time - $subject" >> $logFile
				"sending email $time" >> "$logDir\CurrentProcess.log"
				If ($EmailSubject -match "FAILED") {
					Send-MailMessage -to $notifyEmail -From 'support@mks.com' -Body $emailBody -SmtpServer $smtp -Subject $EmailSubject -BodyAsHtml -Attachments "$logDir\ErrorLog.log"
				} Else {
					Send-MailMessage -to $notifyEmail -From 'support@mks.com' -Body $emailBody -SmtpServer $smtp -Subject $EmailSubject -BodyAsHtml
				}
			}
		}
	}
}
#final modifications to the issues in these queries
im editissue --hostname=$hostname --port=7001 --query="Incident Tickets Created by Automation Script in complete state" --field="Assigned User=Servicer Support Queue"
im editissue --hostname=$hostname --port=7001 --query="Incident Tickets Created by Automation Script in Initial Classification" --field="Assigned User=Remediation Queue" --field="State=Escalated Tier 2" --field="Send Escalation Notification to Client=No"
#script clean up (release the COM object, but leave Outlook running)
im disconnect --hostname=$hostname --port=7001 --yes
#$outlook.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($outlook)
#Get-Process outlook | Stop-Process