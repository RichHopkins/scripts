$Environment = "Alpha"
$server = "TXV12SQEQNQ21"
$DestinationDB = "reotrans"
if (!($env:ColumnName)) {
	"************************************************"
	"************************************************"
	"***+ CategoryInfo:Column name is null (Blank)***"
	"************************************************"
	"************************************************"
	Break; exit
}
if (([string]::IsNullOrEmpty($env:ColumnName.trim()))) {
	"************************************************"
	"************************************************"
	"***+ CategoryInfo:Column name is null (Blank)***"
	"************************************************"
	"************************************************"
	Break; exit
}

if (!($env:ColumnVal)) {
	"************************************************"
	"************************************************"
	"***+ CategoryInfo:Column Value is null (Blank)***"
	"************************************************"
	"************************************************"
	Break; exit
}
if (([string]::IsNullOrEmpty($env:ColumnVal.trim()))) {
	"************************************************"
	"************************************************"
	"***+ CategoryInfo:Column Value is null (Blank)***"
	"************************************************"
	"************************************************"
	Break; exit
}
if (!($env:whereSt)) {
	"************************************************"
	"************************************************"
	"***+ CategoryInfo:Column name is null (Blank)***"
	"************************************************"
	"************************************************"
	Break; exit
}
if (([string]::IsNullOrEmpty($env:whereSt.trim()))) {
	"************************************************"
	"************************************************"
	"***+ CategoryInfo:Where condition is null (Blank)***"
	"************************************************"
	"************************************************"
	Break; exit
}
if (!($env:whereSt | where { $_ -match "=|in" })) {
	"************************************************"
	"************************************************"
	"***+ CategoryInfo:Where condition should have either '=' or 'in'***"
	"************************************************"
	"************************************************"
	Break; exit
}
if ($env:tableName -eq 'Select Table Name') {
	"************************************************"
	"************************************************"
	"***+ CategoryInfo:Select valid Table name***"
	"************************************************"
	"************************************************"
	Break; exit
}
$env:ColumnName = $env:ColumnName.trim()
$env:ColumnVal = $env:ColumnVal.trim()
if (Test-Path $env:whereSt) { $env:whereSt = $env:whereSt.trim() }
$Environment
$DestinationDB

Function RunSQL {
	$script:sqlStatement = 'update ' + $env:tableName + ' set ' + $env:ColumnName + '=' + "'" + $env:ColumnVal + "'" + ' where ' + $env:whereSt
	"********************************************************************************"
	$script:sqlStatement
	$server
	$DestinationDB
	"********************************************************************************"
	Sqlcmd -S $server -Q "$script:sqlStatement" -d $DestinationDB -t 10 > c:\SQLoutput.txt
	Get-Content c:\SQLoutput.txt
	$isErrorThere = Get-Content c:\SQLoutput.txt | where { $_ -match "Msg|HResult|Unexpected" }
	if ($isErrorThere) {
		"***************************************************************************************"
		"***+ CategoryInfo:Error occured while running script***"
		"***************************************************************************************"
		Break; exit
	}
}
Function ValidateSql {
	"*******************************************"
	$script:sqlStatement = 'set nocount on; select count(1) From ' + $env:tableName + ' with (nolock)'
	if ($env:whereSt) {
		$script:sqlStatement += ' where ' + $env:whereSt
	}
	"********************************************************************************"
	$script:sqlStatement
	$server
	$DestinationDB
	"********************************************************************************"
	$SQLRes = Sqlcmd -S $server -Q "$script:sqlStatement" -d $DestinationDB -t 10
	$isErrorThere = $SQLRes | where { $_ -match "Msg|HResult|Unexpected" }
	$isErrorThere > c:\SQLoutput1.txt
	if ($isErrorThere) {
		$isErrorThere
		"***************************************************************************************"
		"***+ CategoryInfo:Error occured while running script***"
		"***************************************************************************************"
		Break; exit
	}
	$SQLCount = ($SQLRes | select -first 1 -skip 2).trim()
	"******************************************"
	"**********Updates $SQLCount Rows**********"
	"******************************************"
	if ([int]$SQLCount -eq 0) {
		"***************************************************************************************"
		"***+ CategoryInfo: No(0) rows are getting updated, change where clause and rerun the job***"
		"***************************************************************************************"
		Break; exit
	}
	if ([int]$SQLCount -le 5) {
		RunSQL
	}
	else {
		"***************************************************************************************"
		"***+ CategoryInfo:More than 5 rows are getting updated, change where clause and rerun the job***"
		"***************************************************************************************"
		Break; exit
	}
	#"*******************************************"
}
ValidateSql