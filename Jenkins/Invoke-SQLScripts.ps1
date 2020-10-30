Import-Module eqDevOps
Import-Module ActiveDirectory

#region Script Functions
function Test-XML {
    [CmdletBinding()]
    [OutputType([bool])]
    param
    (
        [Parameter(Mandatory = $true,
                   ValueFromPipeline = $true)]
        [string]$XmlFile,
        [Parameter(Mandatory = $true)]
        [string]$SchemaFile,
        [scriptblock]$ValidationEventHandler = {
            Write-Error $args[1].Exception
        }
    )

    $xml = New-Object System.Xml.XmlDocument
    $schemaReader = New-Object System.Xml.XmlTextReader $SchemaFile
    $schema = [System.Xml.Schema.XmlSchema]::Read($schemaReader, $ValidationEventHandler)
    $xml.Schemas.Add($schema) | Out-Null
    Try {
        $xml.Load($XmlFile)
        $validate = ($xml.Validate($ValidationEventHandler) 2>&1)
        If (!($validate)) {
            Return $true
        } Else {
            Return $false
        }
    } Catch {
        Return $false
    }
}

Add-Type @'
public class Script
{
    public string cpid = null;
    public string path = null;
    public string devname = null;
    public string devmail = null;
}
'@
function Add-Script ($cpid, $path, $devname, $devmail) {
    $temp = New-Object Script
    $temp.cpid = $cpid
    $temp.path = $path
    $temp.devname = $devname
    $temp.devmail = $devmail
    return [Script]$temp
}

<##This is the original function that requires the filename to be correct
function Get-ReleaseInstructions {
    [CmdletBinding()]
    [OutputType([bool])]
    param ($crid,
        $outPath,
        $instructionFile = "ReleaseInstructions.xml")
    #this is dumb...
    #IM.exe outputs everything through stderr. so I have to redirect the error pipeline to the output pipeline (2>&1) and read it as an Exception.
    $result = im.exe extractattachments --user=$MKSUser --password=$MKSPass --issue=$crid --field="Attachments" --outputFile="$outPath" --overwriteExisting $instructionFile 2>&1
    if ($result.Exception -match "extracted") {
        return $true
    } else {
        return $false
    }
}#>

function Get-ReleaseInstructions {
    param ($crid,
        $outPath)
    if (!(Test-Path $outPath)) {
        mkdir $outPath -Force
    }
    Push-Location $outPath
    im.exe extractattachments --issue=$crid --field="Attachments" --overwriteExisting > $null
    Pop-Location
}

function Confirm-ReleaseInstructions {
    [CmdletBinding()]
    [OutputType([bool])]
    param ($crid,
        $outPath,
        $developerMail)
    $instructFile = Get-ChildItem -Filter "*releaseinstructions*" -Path $outPath
    if ($instructFile.Name -ceq "ReleaseInstructions.xml") {
        return $true
    } elseif ($instructFile) {
        If ($arrCRNameEmailed -notmatch $crid) {
            #Write-Output "Sending bad named file email"
            $parameters = @{
                SmtpServer   = "smtp-dev"
                To           = $developerMail
                Cc           = "_COE.EntArch.DevOps@equator.com"
                From         = "_COE.EntArch.DevOps@equator.com"
                Subject      = "SQL Release Instructions Invalid Name!"
                Body         = "The file $($instructFile.Name) for $crid was named incorrectly.  The file needs to be named 'ReleaseInstructions.xml' exactly.<br><br>We've processed the file for now, but shortly incorrect files will be rejected."
                BodyAsHtml   = $true
            }
            Send-MailMessage @parameters
            $arrCRNameEmailed = $arrCRNameEmailed + $crid
        }
        $releasePath = $instructFile.Directory.ToString()
        $instructFile.MoveTo("$releasePath\ReleaseInstructions.xml", 1) | Out-Null
        return $false
    } else {
        return $false
    }
}

function Get-CPFiles {
    param
    (
        [ValidateNotNullOrEmpty()]
        [string]$cpid,
        [ValidateNotNullOrEmpty()]
        [int64]$cpCount,
        [ValidateNotNullOrEmpty()]
        [string]$crid
    )

    [bool]$SchemaTest = $true
    $CPIDInsertFile = "$CPFolder\$($cpid.Replace(":", "_")).txt"
    Write-Output "Getting files for $cpid"
    $GetCPDetails = si.exe viewcp --yes --user=$MKSUser --password=$MKSPass --format="{revision},{variant},{member},{project},{user},{id}\n" --headerformat="" $cpid
    Write-Output "Checking for Release Instructions..."
    $strInstructionPath = "$BuildFolder\$crid"
    $crMail = $allCRs.Get_Item("$crid")
    If (!($crMail)) {
        $crMail = "_COE.EntArch.DevOps@equator.com"
    }
    Get-ReleaseInstructions -crid $crid -outPath $strInstructionPath
    [bool]$instructionsFound = Confirm-ReleaseInstructions -crid $crid -outPath $strInstructionPath -developerMail $crMail
    if ($instructionsFound) {
        Write-Output "Instructions Found... Validating..."
        [bool]$SchemaTest = Test-XML -XmlFile "$strInstructionPath\ReleaseInstructions.xml" -SchemaFile "D:\ReleaseInstructions.xsd"
        Write-Output "XML Validation is $SchemaTest"
    } else {
        Write-Output "No instructions found."
    }
    if ($SchemaTest -eq $false -and $arrCRSchemaEmailed -notmatch $crid) {
        Write-Output "Sending schema mail to $crMail"
        $parameters = @{
            SmtpServer   = "smtp-dev"
            To           = $crMail
            Cc           = "_COE.EntArch.DevOps@equator.com"
            From         = "_COE.EntArch.DevOps@equator.com"
            Subject      = "SQL Release Instructions Failed - CR $crid!"
            Body         = "The schema for your ReleaseInstructions.xml were found to be in error and ignored durring this Alpha build.<br><br>Your scripts still ran, but they may have run out of order.<br><br>"
            BodyAsHtml   = $true
        }
        Send-MailMessage @parameters
        $arrCRSchemaEmailed = $arrCRSchemaEmailed + $crid
    }
    foreach ($CPContent in $GetCPDetails) {
        [array]$arrScripts = @()
        $executionOrder = 0
        $cpCount++
        $a = $CPContent -split ","
        $FileRev = ($a[0])
        $FileVariant = ($a[1])
        $FileName = ($a[2])
        $FileProject = ($a[3])
        $FileDev = ($a[4])
        $FileDev = $FileDev -match '\(.*\)' | Out-Null
        $developer = $matches[0] -replace '[()]', ''
        $FileID = ($a[5]).Replace(":", "_")

        If ($developer -ne "andrea.fernandes") {
            Try {
                $developerMail = Get-ADUser $developer -Properties mail -ErrorAction Stop
                $developerMail = $developerMail.mail
            } Catch {
                $developerMail = "$developer@equator.com"
            }
        }

        if ($instructionsFound -and $SchemaTest) {
            $script:orderedCount = 1 + $cpCount
            $instructions = Get-XMLFile -xmlFile "$strInstructionPath\ReleaseInstructions.xml"
            Write-Output "Processing Release Instructions"
            $xpath = "/ReleaseInstructions/database/dataScripts"
            If ($instructions.ReleaseInstructions.database.dataScripts.environment.name -contains "ALL") {
                $allEnvScripts = (Select-Xml -Xml $instructions -XPath "$xpath/environment[@name='ALL']" -ErrorAction SilentlyContinue).get_node()
            }
            if ($allEnvScripts) {
                foreach ($script in $allEnvScripts.script) {
                    $scriptPath = ($script.path).Replace("/", "\")
                    $arrScripts += $scriptPath
                }
            }
            If ($instructions.ReleaseInstructions.database.dataScripts.environment.name -contains "Alpha") {
                $envScripts = (Select-Xml -Xml $instructions -XPath "$xpath/environment[@name='Alpha']" -ErrorAction SilentlyContinue).get_node()
            }
            if ($envScripts) {
                foreach ($script in $envScripts.script) {
                    $scriptPath = ($script.path).Replace("/", "\")
                    $arrScripts += $scriptPath
                }
            }
            ForEach ($envName in $instructions.ReleaseInstructions.database.dataScripts.environment) {
                If ($envName.name -ne "ALL" -or $envName.name -ne "Alpha") {
                    $environment = $envName.name
                    $extraScripts = (Select-Xml -Xml $instructions -XPath "$xpath/environment[@name='$environment']" -ErrorAction SilentlyContinue).get_node()
                    foreach ($script in $extraScripts.script) {
                        $scriptPath = ($script.path).Replace("/", "\")
                        $arrExcludeScripts += $scriptPath
                    }
                }
            }
        } elseif ($FileProject.ToLower().Contains("/tables/")) {
            $executionOrder = 51000 + $cpCount
        } elseif ($FileProject.ToLower().Contains("/views/")) {
            $executionOrder = 52000 + $cpCount
        } elseif ($FileProject.ToLower().Contains("/functions/")) {
            $executionOrder = 53000 + $cpCount
        } elseif ($FileProject.ToLower().Contains("/storedprocedures/")) {
            $executionOrder = 54000 + $cpCount
        } elseif ($FileProject.ToLower().Contains("/scripts/")) {
            $executionOrder = 55000 + $cpCount
        } elseif ($FileProject.ToLower().Contains("/indexes/")) {
            $executionOrder = 56000 + $cpCount
        } else {
            $executionOrder = 57000 + $cpCount
        }
        if ($FileProject -match "servicemart") {
            $targetFile = $FileProject.Replace('/', '\').Replace('\project.pj', "").tolower().Replace('\database', "$SQLFolder") + "\$FileName"
        } else {
            $targetFile = $FileProject.Replace('/', '\').Replace('\project.pj', "").tolower().Replace('\database', "$SQLFolder") + "\$FileName"
        }

        foreach ($DBname in $DBList) {
            $currentDBName = $DBname.tolower()
            if ($targetFile.Contains("\$currentDBName\")) {
                Write-Output "Processing: $targetFile"
                #CHECK FOR ORDERING
                foreach ($orderedFile in $arrScripts) {
                    $script:orderedCount++
                    if ($orderedFile -match $FileName) {
                        $executionOrder = $script:orderedCount
                    } else {
                        $executionOrder = 200 + $cpCount
                    }
                }

                # PROCESS FILE
                #Copy file to deploy area
                $FileDir = "$BuildFolder" + $FileProject.Replace('/', '\').Replace('\project.pj', '').ToLower().Replace('\database', '')
                $newFile = "$FileDir\$FileName"
                If (!(Test-Path $FileDir)) {
                    mkdir -Path $FileDir -Force
                }
                Try {
                    Copy-Item -Path $targetFile -Destination $newFile -Force
                } Catch {
                    Write-Output "Send file not found email"
                    $parameters = @{
                        SmtpServer   = "smtp-dev"
                        To           = $developerMail
                        Cc           = "_COE.EntArch.DevOps@equator.com"
                        From         = "_COE.EntArch.DevOps@equator.com"
                        Subject      = "SQL file not found!"
                        Body         = "$targetFile was in CP $cpid to be run, but the file was not found in the DevInt variant!<br><br>"
                        BodyAsHtml   = $true
                    }
                    Send-MailMessage @parameters
                }

                Try {
                    $scriptObj = Add-Script -cpid $FileID -path $newFile -devname $developer -devmail $developerMail
                    Write-Output "ADDING EXECUTION $executionOrder"
                    If ($executionOrder -eq $null) {
                        Write-Output "SOMEHOW THE EXECUTION ORDER IS NULL!!!"
                    } else {
                        $scriptList.Add($executionOrder, $scriptObj)
                    }
                } Catch {
                    Write-Error -Message "Something went wrong trying to add the script $newFile!"
                    Write-Output $_.Exception.ToString()
                }
                "$dtBuildTime - Unordered file:" | Out-File $CPIDInsertFile -Append
                "$newFile" | Out-File $CPIDInsertFile -Append
            }
        }
    }
    $script:cpstartCount = $cpCount
}

function Send-DevNotification {
    param
    (
        [string]$cpid,
        [string]$usermail,
        [string[]]$attach
    )

    $subject = "ALPHA SQL SCRIPT FAILURE - $cpid"
    $body = "There was an error when running the SQL script for your Change Package: <b><font color=red>$cpid</b></font><BR>"
    $body += "Please see the attached log file for details.<BR><BR>"
    $body += "Contact DevOps for any assistance.<BR><BR>"
    $body += "Equator DevOps Team<BR>"
    $body += "eqdevops@equator.com<BR><BR>"
    $parameters = @{
        SmtpServer   = "smtp-dev"
        To           = $usermail
        Cc           = "_COE.EntArch.DevOps@equator.com"
        From         = "_COE.EntArch.DevOps@equator.com"
        Subject      = $subject
        Body         = $body
        BodyAsHtml   = $true
        Attachments  = $attach
    }
    Send-MailMessage @parameters
}
#endregion

#################
#START OF SCRIPT#
#################

#JENKINS VARS
$MKSUser = $env:MKSUser
$MKSPass = $env:MKSPassword
$EQDevIntBuildID = $env:DevIntBuildID
$releaseID = $EQDevIntBuildID -split "-"
$releaseID = $releaseID[0]
$BuildFolder = "D:\Deploy\Release\SQL\Builds\$EQDevIntBuildID"
if (!(Test-Path $BuildFolder)) {
    mkdir $BuildFolder
}
$DBList = @("CW_IMPORT",
    "Environments",
    "Equator_Meta",
    "integration",
    "Loan_Management",
    "Reap", "Reotrans",
    "Rule_Matrix_Configuration",
    "Segmentation",
    "servicemart",
    "Reports",
    "EQLogs",
    "Reotransreadonly_Audit")
$CPFolder = "D:\Deploy\Release\SQL\control\CPID"
if (!(Test-Path $CPFolder)) {
    mkdir $CPFolder
}
$SQLFolder = "D:\Workspace\variants\devint\sql"
if (!(Test-Path $SQLFolder)) {
    mkdir $SQLFolder
}
$errorLog = "$BuildFolder\ErrorLog.log"
#New-Item -Path $errorLog -ItemType file
$script:cpstartCount = 1
[array]$arrScripts = @()
[array]$arrExcludeScripts = @()
[hashtable]$allCRs = @{ }
[array]$arrCRNameEmailed = @()
[array]$arrCRSchemaEmailed = @()
#This will be the list of scripts that keeps them stored by priority, then runs them in order later
$scriptList = New-Object 'System.Collections.Generic.SortedDictionary[int64,Script]'

#region Connect-MKS
si.exe connect --user=$MKSUser --password=$MKSPass --yes
Write-Output "Connected to MKS."
#endregion Connect-MKS

#region Get-BuildDateParams
foreach ($content in Get-Content "D:\Deploy\Scripts\CI\lastBuildTime.txt") {
    $dtLastBuild = $content
    Write-Output "Last Build Date: $content"
}
foreach ($content in Get-Content "D:\Deploy\Scripts\CI\nextBuildTime.txt") {
    $dtNextBuild = $content
    Write-Output "Current Build Date: $content"
}
#endregion Get-BuildDateParams

#region Update-CPQuery
$qD = "((field[Environment] = Dev Int) and (genericcp:si:attribute[closeddate] between time $dtLastBuild and $dtNextBuild) and (field[Type] = Back Promote Task,Propagation Task) and (field[Configuration Project] = database))"
im.exe  editquery --yes --user=$MKSUser --password=$MKSPass --queryDefinition="$qD" "Dev Int commits in arbitrary time range"
Write-Output "Updated MKS CP Query."
#endregion Update-CPQuery

#region Run-MKSQueries
$CPIDS = si.exe viewcps --yes --user=$MKSUser --password=$MKSPass --query='Dev Int commits in arbitrary time range' --fields="ID,Summary"
Write-Output "Execute MKS CP Query."
$CRIDS = im.exe issues --yes --user=$MKSUser --password=$MKSPass --query='CRs for Release' --fields="ID,Primary Developer Assigned" --fieldsDelim=";"
Write-Output "Execute MKS CR Query."
foreach ($CR in $CRIDS) {
    $CRdata = $CR -split ";"
    $id = $CRdata[0]
    $CR -match '\(.*\)' | Out-Null
    $dev = $matches[0] -replace "[()]", ""
    $devMail = Get-ADUser $dev -Properties mail
    $devMail = $devMail.mail
    $allCRs.Add($id, $devMail)
}
#endregion Run-MKSQueries

#region Process-CPIDs
foreach ($CPID in $CPIDS) {
    $script:cpstartCount++
    $strCPID = (($CPID -split "`t")[0])
    (($CPID -split "`t")[1]) -match "(for CR \d{6,7})" | Out-Null
    $strCRID = $matches[0]
    $strCRID -match "(\d{6,7})" | Out-Null
    $strCRID = $matches[0]
    $CPIDString = $strCPID.Replace(":", "_")
    $CPIDFile = "$CPFolder\$CPIDString.txt"
    Write-Output "Processing CP $CPIDString"
    if (-not (Test-Path  ($CPIDFile))) {
        New-Item -Path $CPIDFile -ItemType file -Value "$dtBuildTime processed CP." -force
        Write-Output "Getting files for CP $CPIDFile"
        Get-CPFiles -cpid $strCPID -cpCount $script:cpstartCount -crid $strCRID
    } else {
        Write-Output "Skipping files for CP $CPIDFile"
    }
}
#endregion RegionName

Write-Output ""
Write-Output "DEBUG INFO!"
Write-Output ""
$scriptList.GetEnumerator() | ForEach-Object {
    $item = $_.Key
    $item = $scriptList.Get_Item($item)
    $cpid = $item.cpid
    $devname = $item.devname
    $devmail = $item.devmail
    $sqlFile = $item.path
    Write-Output "Key: $($_.Key)"
    Write-Output "DevName: $devname"
    Write-Output "DevMail: $devmail"
    Write-Output "DevFile: $sqlFile"
    Write-Output ""
}

#region Process-OrderedRequest
if (!$scriptList -or $scriptList.Count -eq 0) {
    Write-Output "No scripts files to process."
} else {
    Write-Output "Executing SQL for ordered files."
    $scriptList.GetEnumerator() | ForEach-Object {
        $item = $_.Key
        $item = $scriptList.Get_Item($item)
        $cpid = $item.cpid
        $devname = $item.devname
        $devmail = $item.devmail
        $sqlFile = $item.path
        $DBFound = 0
        $DBServer = ""
        foreach ($DBname in $DBList) {
            $currentDBName = $DBname.tolower()
            if ($sqlFile.Contains("\$currentDBName\")) {
                $currDB = $DBname
                switch ($DBname) {
                    "CW_IMPORT" {
                        $DBServer = "TXV8SQEQNQ02"
                    }
                    "Environments" {
                        $DBServer = "TXV8SQEQNQ01"
                    }
                    "Equator_Meta" {
                        $DBServer = "TXV8SQEQNQ01"
                    }
                    "integration" {
                        $DBServer = "TXV8SQEQNQ02"
                    }
                    "Loan_Management" {
                        $DBServer = "TXV8SQEQNQ02"
                    }
                    "Reap" {
                        $DBServer = "TXV8SQEQNQ02"
                    }
                    "Reotrans" {
                        $DBServer = "TXV8SQEQNQ01"
                    }
                    "Rule_Matrix_Configuration" {
                        $DBServer = "TXV8SQEQNQ01"
                    }
                    "Segmentation" {
                        $DBServer = "TXV8SQEQNQ01"
                    }
                    "servicemart" {
                        $DBServer = "TXV8SQEQNQ02"
                    }
                    "Reports" {
                        $DBServer = "TXV8SQEQNQ01"
                    }
                    "EQLogs" {
                        $DBServer = "TXV8SQEQNQ01"
                    }
                    "Reotransreadonly_Audit" {
                        $DBServer = "TXV8SQEQNQ01"
                    }
                }
                Write-Output "For $DBname, attempting $sqlFile file."
                $DBFound = 1
            }
        }
        if ($DBFound -eq 1) {
            if ($arrExcludeScripts -notcontains $filename) {
                #Write-Output "Running: Sqlcmd -S $DBServer -i $sqlFile -I -d $currDB -o ""$sqlFile.log"" for $cpid"
                Sqlcmd -S $DBServer -i $sqlFile -I -d $currDB -o "$sqlFile.log"
                $isErrorThere = Get-Content "$sqlFile.log" -WarningAction SilentlyContinue | Where-Object {
                    $_ -match "Msg|HResult|Unexpected"
                } -WarningAction SilentlyContinue
                if ($isErrorThere) {
                    $filename = Split-Path $sqlFile -Leaf
                    Write-Output "Opening Integrity issue for CP $cpid, assigned to $devname"
                    $attachment = "$sqlFile.log" -replace "\\", "/"
                    #Opening issues in Dev Int instead of Alpha so issue count doesn't dig the devs.
                    #im.exe createissue --type="Issue" --field="Summary=Error executing SQL script $filename" --field="Assigned User=$devname" --field="Tester Assigned=$devname" --field="Environment Discovered In=Dev Int" --field="Issue Category=Software Defect: Database" --field="Issue Exists in Prod when Discovered=No" --field="Issue Found by Client=No" --field="Module=Architecture (ARC)" --field="Web Browser=Not Applicable" --field="Severity=Unusable" --field="Issue Found In=Release $releaseID" --field="Issue Initiative=Acceptance Testing" --field="Client=Equator" --field="Issue Exists In=Alpha" --field="Workstation=Equator" --field="Steps to Reproduce=Run SQL script" --field="Expected Results=No Errors" --field="Actual Results=Errors" --addAttachment="field=Attachments,path=$attachment,name=error.log"
                    Send-DevNotification -cpid $cpid -userid $devmail -attach "$sqlFile.log"
                    "Error executing $sqlFile" | Out-File $errorLog -Append
                    Write-Output "Error executing $sqlFile "
                } else {
                    Write-Output "Success executing $sqlFile "
                }
            }
        } else {
            "No DB found for $sqlFile" | Out-File $errorLog -Append
        }
    }
}
#endregion Process-OrderedRequest

#region Quit-MKS
si.exe disconnect --user=$MKSUser --password=$MKSPass --yes
Write-Output "Disconnected from MKS."
si.exe exit --user=$MKSUser --password=$MKSPass --yes
Write-Output "Exited MKS."
#endregion Quit-MKS

#region Set-NextBuildTime
Write-Output $dtNextBuild | Out-File "D:\Deploy\Scripts\CI\lastBuildTime.txt"
Write-Output "Updated lastBuildTime file."
#endregion Set-NextBuildTime