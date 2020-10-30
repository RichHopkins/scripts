$script:smtp="smtp-dev.rtllc.local" 
$script:notifyEmail='ramesh.balajepalli@equator.com','sellerhelp@equator.com'
#$script:notifyEmail='ramesh.balajepalli@equator.com',
$script:SrcEmailDomain='@fannie'
$script:allowedList=@('EQBusiness_Support@fanniemae.com','David_Box@fanniemae.com','Shashank_Davanagere@fanniemae.com','Srinivas_Rayapati@fanniemae.com','danny_p_keough@fanniemae.com','nibu_paul@fanniemae.com ','Natasha_T_Sheffield@fanniemae.com','Lynna_M_Theimer@fanniemae.com','David_L_Jones@fanniemae.com','Jordan_Velasco@fanniemae.com','Sailakshmi_subramanian@fanniemae.com','Anjana_vellingiri@fanniemae.com','John_thibaudeau@fanniemae.com','Jacob_s_williamson@fanniemae.com')
$script:now=Get-Date -format "dd-MMM-yyyy HH:mm" 
$script:CuurTime=Get-Date -format "dd-MMM-yyyy HH:mm" 
$now=Get-Date -format "dd-MMM-yyyy"
$script:logDir="c:\scripts\Logs-Test\$now\"
$script:logFile="$script:logDir\LogFIle.txt"
$script:IsThereAttachment=$true
$script:attchmentPath='c:\temp'
if(!(Test-Path $script:logDir)) {
    mkdir $script:logDir -Force
}
 "Started at -"+$script:CuurTime >> "$script:logDir\Scheduler.log"  
 "Step 1 - "+ (Get-Date -format "dd-MMM-yyyy HH:mm")  > "$script:logDir\CurrentProcess.log" 
 $unReadEmailLog="$script:logDir\Unread_Emails.txt"
 if(!(Test-Path $unReadEmailLog)){
    "Started at - "+$script:CuurTime >> $unReadEmailLog  
 }
"****************************"
"Make sure you are logged in MKS"
"Domain filter is case sensitive-double check that"
"****************************"

Function Get-OutlookInBox
{
	Add-type -assembly "Microsoft.Office.Interop.Outlook" | out-null
	$olFolders = "Microsoft.Office.Interop.Outlook.olDefaultFolders" -as [type]
	$olSaveType = "Microsoft.Office.Interop.Outlook.OlSaveAsType" -as [type] 
	$outlook = new-object -comobject outlook.application
	$namespace = $outlook.GetNameSpace("MAPI")
	$folder = $namespace.getDefaultFolder($olFolders::olFolderInBox)
    "Step 3 - Loaded outlook objects - "+ (Get-Date -format "dd-MMM-yyyy HH:mm")  >> "$script:logDir\test.log" 
	foreach ($email in $folder.items )
		{    
		$script:CuurTime +'-'+$email.subject >> "$script:logDir\All_Emails.txt" 
		if($email.unread -eq 'True')
			{ 
				"Step 4 - $email.subject - "+ (Get-Date -format "dd-MMM-yyyy HH:mm")  >> "$script:logDir\test.log" 
			}
	} 
}

Get-OutlookInBox