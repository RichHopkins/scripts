<#
	.SYNOPSIS
		Converts an Excel sheet from a workbook to JSON
	
	.DESCRIPTION
		To allow for parsing of Excel Workbooks suitably in PowerShell, this script converts a sheet from a spreadsheet into a JSON file of the same structure as the sheet.
	
	.PARAMETER InputFile
		The Excel Workbook to be converted. Can be FileInfo or a String.
	
	.PARAMETER OutputFileName
		A description of the OutputFileName parameter.
	
	.PARAMETER SheetName
		The name of the sheet from the Excel Workbook to convert. If only one sheet exists, it will convert that one.
	
	.PARAMETER state
		A description of the state parameter.
	
	.EXAMPLE
		Convert-ExcelSheetToJson -InputFile MyExcelWorkbook.xlsx
	
	.EXAMPLE
		Get-Item MyExcelWorkbook.xlsx | Convert-ExcelSheetToJson -SheetName Sheet2
	
	.NOTES
		Written by: Chris Brown
		Modified by: Rich Hopkins
	
	.LINK
		https://flamingkeys.com/convert-excel-sheet-json-powershell
#>
[CmdletBinding()]
param
(
	[Parameter(Mandatory = $true,
			   ValueFromPipeline = $true)]
	[Object]$InputFile,
	[string]$OutputFileName,
	[string]$SheetName,
	[Parameter(Mandatory = $true)]
	[ValidateSet('NEW', 'update', IgnoreCase = $false)]
	[string]$state
)

class Jams {
	[string]$advanceWarning;
	[string]$agentNode;
	[string]$description;
	[string]$jobName;
	[string]$notifyEMail;
	[int]$notifyJobID;
	[string]$notifyJobName;
	[bool]$notifyJobNameIsRelative;
	[bool]$notifyOfMissedWindow;
	[string]$notifyOther;
	[string]$notifySeverity;
	[bool]$notifyUser;
	[string]$notifyUsers;
	[string[]]$parameters;
	[string]$precheckInterval;
	[int]$precheckJobID;
	[string]$precheckJobName;
	[bool]$precheckJobNameIsRelative;
	[int]$recoverJobID;
	[string]$recoverJobName;
	[bool]$recoverJobNameIsRelative;
	[string]$recoveryInstructions;
	[string]$recoverySeverity;
	[string[]]$reports;
	[bool]$restartable;
	[string]$resubmitEnd;
	[bool]$resubmitOnError;
	[string]$retainOption;
	[string]$retainTime;
	[int]$retryCount;
	[string]$retryInterval;
	[string]$runawayAction;
	[string]$runawayElapsed;
	[int]$runawayElapsedPer;
	[int]$runPriority;
	[string]$scheduledDateEnd;
	[string]$scheduledDateStart;
	[string]$scheduleFromTime;
	[string]$scheduleToTime;
	[int]$scheduleWindowID;
	[string]$scheduleWindowName;
	[int]$schedulingPriorityModifier;
	[string]$shortElapsed;
	[int]$shortElapsedPer;
	[string]$shortSeverity;
	[string]$specificInformational;
	[string]$specificValues;
	[string]$specificWarning;
	[string]$stalledTime;
	[int]$submitMethodID;
	[string]$submitMethodName;
	[bool]$submitOnHold;
	[bool]$suppressMenuDisplay;
	[string]$timestampLogs;
	[int]$timeZoneID;
	[string]$timeZoneName;
	[int]$userID;
	[string]$userName;
	[int]$workingSetDefault;
	[int]$workingSetMax;
	[int]$workingSetQuota;
}

class eqSetting {
	[string]$_Environment;
	[string]$_IPAddress;
	[bool]$autoSubmit;
	[string]$exceptForDate;
	[string]$parentFolderName;
	[string]$resubmitBase;
	[string]$resubmitDelay;
	[string]$scheduledDate;
	[string]$scheduledTime;
	[string]$source;
}

class QASettings {
	[string]$ExpectedResults;
	[string]$Testable;
	[string]$TestSetup;
	[string]$TestSteps;
}

class JamsData {
	[Jams[]]$Jams;
	[string]$state;
	[eqSetting[]]$eqSettings;
	[QASettings[]]$QASettings;
	JamsData([Jams[]]$Jams, [string]$state, [eqSetting[]]$eqSettings, [QASettings[]]$QASettings) {
		$this.Jams = $Jams
		$this.state = $state
		$this.eqSettings = $eqSettings
		$this.QASettings = $QASettings
	}
}

#region prep
# Check what type of file $InputFile is, and update the variable accordingly
if ($InputFile -is "System.IO.FileSystemInfo") {
	$InputFile = $InputFile.FullName.ToString()
}
# Make sure the input file path is fully qualified
$InputFile = [System.IO.Path]::GetFullPath($InputFile)
$OutputDir = Split-Path $InputFile
Write-Verbose "Converting '$InputFile' to JSON"

# Instantiate Excel
$excelApplication = New-Object -ComObject Excel.Application
$excelApplication.DisplayAlerts = $false
$Workbook = $excelApplication.Workbooks.Open($InputFile)

# If SheetName wasn't specified, make sure there's only one sheet
if (-not $SheetName) {
	if ($Workbook.Sheets.Count -eq 1) {
		$SheetName = @($Workbook.Sheets)[0].Name
		Write-Verbose "SheetName was not specified, but only one sheet exists. Converting '$SheetName'"
	} else {
		throw "SheetName was not specified and more than one sheet exists."
	}
} else {
	# If SheetName was specified, make sure the sheet exists
	$theSheet = $Workbook.Sheets | Where-Object { $_.Name -eq $SheetName }
	if (-not $theSheet) {
		throw "Could not locate SheetName '$SheetName' in the workbook"
	}
}
Write-Verbose "Outputting sheet '$SheetName' to '$OutputFileName'"
#endregion prep


# Grab the sheet to work with
$theSheet = $Workbook.Sheets | Where-Object { $_.Name -eq $SheetName }

#region rows
$row = 2
Do {
	$Jams = [Jams]::new()
	$Jams.advanceWarning = $theSheet.Cells.Item($row, 1).Value()
	$Jams.agentNode = $theSheet.Cells.Item($row, 2).Value()
	$Jams.description = $theSheet.Cells.Item($row, 3).Value()
	$Jams.jobName = $theSheet.Cells.Item($row, 4).Value()
	$Jams.notifyEMail = $theSheet.Cells.Item($row, 5).Value()
	$Jams.notifyJobID = $theSheet.Cells.Item($row, 6).Value()
	$Jams.notifyJobName = $theSheet.Cells.Item($row, 7).Value()
	$Jams.notifyJobNameIsRelative = $theSheet.Cells.Item($row, 8).Value()
	$Jams.notifyOfMissedWindow = $theSheet.Cells.Item($row, 9).Value()
	$Jams.notifyOther = $theSheet.Cells.Item($row, 10).Value()
	$Jams.notifySeverity = $theSheet.Cells.Item($row, 11).Value()
	$Jams.notifyUser = $theSheet.Cells.Item($row, 12).Value()
	$Jams.notifyUsers = $theSheet.Cells.Item($row, 13).Value()
	$Jams.parameters = $theSheet.Cells.Item($row, 14).Value()
	$Jams.precheckInterval = $theSheet.Cells.Item($row, 15).Value()
	$Jams.precheckJobID = $theSheet.Cells.Item($row, 16).Value()
	$Jams.precheckJobName = $theSheet.Cells.Item($row, 17).Value()
	$Jams.precheckJobNameIsRelative = $theSheet.Cells.Item($row, 18).Value()
	$Jams.recoverJobID = $theSheet.Cells.Item($row, 19).Value()
	$Jams.recoverJobName = $theSheet.Cells.Item($row, 20).Value()
	$Jams.recoverJobNameIsRelative = $theSheet.Cells.Item($row, 21).Value()
	$Jams.recoveryInstructions = $theSheet.Cells.Item($row, 22).Value()
	$Jams.recoverySeverity = $theSheet.Cells.Item($row, 23).Value()
	$Jams.reports = $theSheet.Cells.Item($row, 24).Value()
	$Jams.restartable = $theSheet.Cells.Item($row, 25).Value()
	$Jams.resubmitEnd = $theSheet.Cells.Item($row, 26).Value()
	$Jams.resubmitOnError = $theSheet.Cells.Item($row, 27).Value()
	$Jams.retainOption = $theSheet.Cells.Item($row, 28).Value()
	$Jams.retainTime = $theSheet.Cells.Item($row, 29).Value()
	$Jams.retryCount = $theSheet.Cells.Item($row, 30).Value()
	$Jams.retryInterval = $theSheet.Cells.Item($row, 31).Value()
	$Jams.runawayAction = $theSheet.Cells.Item($row, 32).Value()
	$Jams.runawayElapsed = $theSheet.Cells.Item($row, 33).Value()
	$Jams.runawayElapsedPer = $theSheet.Cells.Item($row, 34).Value()
	$Jams.runPriority = $theSheet.Cells.Item($row, 35).Value()
	$Jams.scheduledDateEnd = $theSheet.Cells.Item($row, 36).Value()
	$Jams.scheduledDateStart = $theSheet.Cells.Item($row, 37).Value()
	$Jams.scheduleFromTime = $theSheet.Cells.Item($row, 38).Value()
	$Jams.scheduleToTime = $theSheet.Cells.Item($row, 39).Value()
	$Jams.scheduleWindowID = $theSheet.Cells.Item($row, 40).Value()
	$Jams.scheduleWindowName = $theSheet.Cells.Item($row, 41).Value()
	$Jams.schedulingPriorityModifier = $theSheet.Cells.Item($row, 42).Value()
	$Jams.shortElapsed = $theSheet.Cells.Item($row, 43).Value()
	$Jams.shortElapsedPer = $theSheet.Cells.Item($row, 44).Value()
	$Jams.shortSeverity = $theSheet.Cells.Item($row, 45).Value()
	$Jams.specificInformational = $theSheet.Cells.Item($row, 46).Value()
	$Jams.specificValues = $theSheet.Cells.Item($row, 47).Value()
	$Jams.specificWarning = $theSheet.Cells.Item($row, 48).Value()
	$Jams.stalledTime = $theSheet.Cells.Item($row, 49).Value()
	$Jams.submitMethodID = $theSheet.Cells.Item($row, 50).Value()
	$Jams.submitMethodName = $theSheet.Cells.Item($row, 51).Value()
	$Jams.submitOnHold = $theSheet.Cells.Item($row, 52).Value()
	$Jams.suppressMenuDisplay = $theSheet.Cells.Item($row, 53).Value()
	$Jams.timestampLogs = $theSheet.Cells.Item($row, 54).Value()
	$Jams.timeZoneID = $theSheet.Cells.Item($row, 55).Value()
	$Jams.timeZoneName = $theSheet.Cells.Item($row, 56).Value()
	$Jams.userID = $theSheet.Cells.Item($row, 57).Value()
	$Jams.userName = $theSheet.Cells.Item($row, 58).Value()
	$Jams.workingSetDefault = $theSheet.Cells.Item($row, 59).Value()
	$Jams.workingSetMax = $theSheet.Cells.Item($row, 60).Value()
	$Jams.workingSetQuota = $theSheet.Cells.Item($row, 61).Value()
	$DevInt = [eqSetting]::new()
	$DevInt._Environment = $theSheet.Cells.Item($row, 62).Value()
	$DevInt._IPAddress = $theSheet.Cells.Item($row, 63).Value()
	$DevInt.autoSubmit = $theSheet.Cells.Item($row, 64).Value()
	$DevInt.exceptForDate = $theSheet.Cells.Item($row, 65).Value()
	$DevInt.parentFolderName = $theSheet.Cells.Item($row, 66).Value()
	$DevInt.resubmitBase = $theSheet.Cells.Item($row, 67).Value()
	$DevInt.resubmitDelay = $theSheet.Cells.Item($row, 68).Value()
	$DevInt.scheduledDate = $theSheet.Cells.Item($row, 69).Value()
	$DevInt.scheduledTime = $theSheet.Cells.Item($row, 70).Value()
	$DevInt.source = $theSheet.Cells.Item($row, 71).Value()
	$Alpha = [eqSetting]::new()
	$Alpha._Environment = $theSheet.Cells.Item($row, 72).Value()
	$Alpha._IPAddress = $theSheet.Cells.Item($row, 73).Value()
	$Alpha.autoSubmit = $theSheet.Cells.Item($row, 74).Value()
	$Alpha.exceptForDate = $theSheet.Cells.Item($row, 75).Value()
	$Alpha.parentFolderName = $theSheet.Cells.Item($row, 76).Value()
	$Alpha.resubmitBase = $theSheet.Cells.Item($row, 77).Value()
	$Alpha.resubmitDelay = $theSheet.Cells.Item($row, 78).Value()
	$Alpha.scheduledDate = $theSheet.Cells.Item($row, 79).Value()
	$Alpha.scheduledTime = $theSheet.Cells.Item($row, 80).Value()
	$Alpha.source = $theSheet.Cells.Item($row, 81).Value()
	$Beta = [eqSetting]::new()
	$Beta._Environment = $theSheet.Cells.Item($row, 82).Value()
	$Beta._IPAddress = $theSheet.Cells.Item($row, 83).Value()
	$Beta.autoSubmit = $theSheet.Cells.Item($row, 84).Value()
	$Beta.exceptForDate = $theSheet.Cells.Item($row, 85).Value()
	$Beta.parentFolderName = $theSheet.Cells.Item($row, 86).Value()
	$Beta.resubmitBase = $theSheet.Cells.Item($row, 87).Value()
	$Beta.resubmitDelay = $theSheet.Cells.Item($row, 88).Value()
	$Beta.scheduledDate = $theSheet.Cells.Item($row, 89).Value()
	$Beta.scheduledTime = $theSheet.Cells.Item($row, 90).Value()
	$Beta.source = $theSheet.Cells.Item($row, 91).Value()
	$REM = [eqSetting]::new()
	$REM._Environment = $theSheet.Cells.Item($row, 92).Value()
	$REM._IPAddress = $theSheet.Cells.Item($row, 93).Value()
	$REM.autoSubmit = $theSheet.Cells.Item($row, 94).Value()
	$REM.exceptForDate = $theSheet.Cells.Item($row, 95).Value()
	$REM.parentFolderName = $theSheet.Cells.Item($row, 96).Value()
	$REM.resubmitBase = $theSheet.Cells.Item($row, 97).Value()
	$REM.resubmitDelay = $theSheet.Cells.Item($row, 98).Value()
	$REM.scheduledDate = $theSheet.Cells.Item($row, 99).Value()
	$REM.scheduledTime = $theSheet.Cells.Item($row, 100).Value()
	$REM.source = $theSheet.Cells.Item($row, 101).Value()
	$Stage = [eqSetting]::new()
	$Stage._Environment = $theSheet.Cells.Item($row, 102).Value()
	$Stage._IPAddress = $theSheet.Cells.Item($row, 103).Value()
	$Stage.autoSubmit = $theSheet.Cells.Item($row, 104).Value()
	$Stage.exceptForDate = $theSheet.Cells.Item($row, 105).Value()
	$Stage.parentFolderName = $theSheet.Cells.Item($row, 106).Value()
	$Stage.resubmitBase = $theSheet.Cells.Item($row, 107).Value()
	$Stage.resubmitDelay = $theSheet.Cells.Item($row, 108).Value()
	$Stage.scheduledDate = $theSheet.Cells.Item($row, 109).Value()
	$Stage.scheduledTime = $theSheet.Cells.Item($row, 110).Value()
	$Stage.source = $theSheet.Cells.Item($row, 111).Value()
	$Prod = [eqSetting]::new()
	$Prod._Environment = $theSheet.Cells.Item($row, 112).Value()
	$Prod._IPAddress = $theSheet.Cells.Item($row, 113).Value()
	$Prod.autoSubmit = $theSheet.Cells.Item($row, 114).Value()
	$Prod.exceptForDate = $theSheet.Cells.Item($row, 115).Value()
	$Prod.parentFolderName = $theSheet.Cells.Item($row, 116).Value()
	$Prod.resubmitBase = $theSheet.Cells.Item($row, 117).Value()
	$Prod.resubmitDelay = $theSheet.Cells.Item($row, 118).Value()
	$Prod.scheduledDate = $theSheet.Cells.Item($row, 119).Value()
	$Prod.scheduledTime = $theSheet.Cells.Item($row, 120).Value()
	$Prod.source = $theSheet.Cells.Item($row, 121).Value()
	$eqSettings = @($DevInt, $Alpha, $Beta, $REM, $Stage, $Prod)
	$QASettings = [QASettings]::new()
	$QASettings.Testable = $theSheet.Cells.Item($row, 122).Value()
	$QASettings.TestSetup = $theSheet.Cells.Item($row, 123).Value()
	$QASettings.TestSteps = $theSheet.Cells.Item($row, 124).Value()
	$QASettings.ExpectedResults = $theSheet.Cells.Item($row, 125).Value()
	$JamsData = [JamsData]::new($Jams, $state, $eqSettings, $QASettings)
	$JamsData | ConvertTo-Json | Out-File -Encoding ASCII -FilePath $OutputFileName
	
	$jobName = $theSheet.Cells.Item($row, 4).Value()
	# Make sure the output file path is fully qualified
	$OutputFileName = [System.IO.Path]::GetFullPath("$OutputDir\$jobName.json")
	$row++
}
While ($jobName)
#endregion rows

# Close the Workbook
$excelApplication.Workbooks.Close()
# Close Excel
[void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($excelApplication)