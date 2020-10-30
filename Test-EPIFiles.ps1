<#
	.SYNOPSIS
		Runs validation of the EPI excel files.
	
	.DESCRIPTION
		Runs validation of the EPI excel files.
	
	.PARAMETER testPath
		Path where the excel files are stored.
	
	.PARAMETER outputFile
		Path to save the output log to.

	.PARAMETER showExcel
		Use this switch to force Excel to be visible and display warnings.
#>
[CmdletBinding()]
param
(
	[Parameter(Mandatory = $true,
			   Position = 0)]
	[ValidateScript({
			Test-Path $_
		})]
	[Alias('path')]
	[string]$testPath,
	[string]$outputFile,
	[switch]$showExcel = $false
)

[void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

#region Start Excel
Write-Verbose "Starting Excel Application"
$excelApplication = New-Object -ComObject Excel.Application
if ($showExcel) {
	Write-Verbose "Debug Enabled"
	$excelApplication.DisplayAlerts = $true
	$excelApplication.Visible = $true
} else {
	$excelApplication.DisplayAlerts = $false
	$excelApplication.Visible = $false
}
$xlup = -4162
#endregion Start Excel

#region functions
function Stop-Excel ($workbook) {
	Write-Verbose "Stopping Excel"
	if ($workbook) {
		$workbook.Close($false)
	}
	$excelApplication.Quit()
	[System.Runtime.Interopservices.Marshal]::FinalReleaseComObject($excelApplication)
	Stop-Process -Name excel
}

function Get-Sheet {
	[CmdletBinding()]
	param
	(
		[ValidateSet('Asset Management EPI Data Set', 'Hubzu EPI Data Set', 'REALResolution EPI Data Set', 'Resware EPI Data Set', 'VMS EPI Data Set')]
		[string]$sheetName,
		$workbook
	)
	
	$theSheet = $workbook.Sheets | Where-Object {
		$_.Name -eq $sheetName
	}
	Write-Verbose "Reading $sheetName"
	if (-not $theSheet) {
		throw "Could not locate Sheet Name '$sheetName' in the workbook $($script:file.Name)"
		Stop-Excel $workbook
		exit
	}
	return $theSheet
}

function Test-ColumnFormat {
	param
	(
		[Parameter(Mandatory = $true,
				   Position = 0)]
		$sheet,
		[Parameter(Mandatory = $true,
				   Position = 1)]
		[int]$column,
		[Parameter(Mandatory = $true,
				   Position = 2)]
		[ValidateSet('text', 'int')]
		[string]$type
	)
	switch ($type) {
		text {$char = '@'}
		int {$char = '0'}
	}
	Write-Verbose "Checking that $($sheet.Columns[$column].Cells[1].Text) column format is set to $type in file $($sheet.Name)"
	if ($sheet.Columns[$column].NumberFormat -ne $char) {
		$sheet.Columns[$column].NumberFormat = $char
		Write-Output "$($sheet.Columns[$column].Cells[1].Text) column was not $type formatted in file $($sheet.Name), but is now" | Out-File $outputFile -Append
	}
}

function Trim-Headers ($sheet) {
	Write-Verbose "Trimming the headers on sheet $($sheet.Name)"
	$intColumns = $sheet.UsedRange.Rows(1).Columns.Count
	for ($i = 1; $i -le $intColumns; $i++) {
		$sheet.Cells.Item(1, $i) = $sheet.Cells.Item(1, $i).Text.Trim()
	}
}

function Convert-ToLetters ([parameter(Mandatory = $true,
							ValueFromPipeline = $true)]
							[int]$value) {
	$currVal = $value
	$returnVal = ''
	while ($currVal -ge 26) {
		$returnVal = [char](($currVal) % 26 + 65) + $returnVal
		$currVal = [int][math]::Floor($currVal / 26)
	}
	$returnVal = [char](($currVal) + 64) + $returnVal
	return $returnVal
}


function Find-Duplicates ($sheet, $column) {
	Write-Verbose "Checking for duplicates in the $($sheet.Cells.Item(1, $column).Text) column on $($sheet.Name)"
	$intRows = $sheet.Cells.Range("A1048576").End($xlup).Row
	$arrColumnData = @()
	for ($i = 2; $i -le $intRows; $i++) {
		$arrColumnData += $sheet.Cells.Item($i, $column).Text
	}
	$uniqueData = $arrColumnData | Select-Object -Unique
	$compareData = Compare-Object -ReferenceObject $arrColumnData -DifferenceObject $uniqueData
	If ($compareData.InputObject) {
		Write-Output "The following duplicates were found in the $($sheet.Cells.Item(1, $column).Text) column, please check $($sheet.Name)" | Out-File $outputFile -Append
		Write-Output $compareData.InputObject | Out-File $outputFile -Append
	}
}

function Test-EmailAddresses ($sheet, $column) {
	Write-Verbose "Validating email addresses on $($sheet.Name)"
	$badEmails = @()
	$allGood = $true
	$intRows = $sheet.cells.Range("A1048576").End($xlup).row
$emailRegex = @"
^[a-zA-Z0-9.!£#$%&'^_`{}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$
"@
	for ($i = 2; $i -le $intRows; $i++) {
		$emailAdress = $sheet.Cells.Item($i, $column).Text
		if ($emailAdress -ne "") {
			[boolean]$test = $emailAdress.Trim() -match $emailRegex
			if ($test -eq $false) {
				$badEmails += $emailAdress
				$allGood = $false
			}
		}
	}
	if ($allGood -eq $false) {
		Write-Output "The following email addresses have errors on sheet $($sheet.Name):" | Out-File $outputFile -Append
		Write-Output $badEmails | Out-File $outputFile -Append
	}
}

function Test-MICode ($sheet) {
	Write-Verbose "Checking MI Code for nulls"
	$allGood = $true
	$badRows = @()
	$intRows = $sheet.cells.Range("A1048576").End($xlup).row
	for ($i = 2; $i -le $intRows; $i++) {
		$MICode = $sheet.Cells.Item($i, 8).Text
		if ($MICode -eq "" -or $MICode -eq $null) {
			$badRows += $i
			$allGood = $false
		}
	}
	if ($allGood -eq $false) {
		Write-Output "The following rows have MI Code errors on sheet $($sheet.Name):" | Out-File $outputFile -Append
		Write-Output $badEmails | Out-File $outputFile -Append
	}
}

function Test-StringInColumn ($sheet, $column, $searchString) {
	if ($searchString -eq '') {
		Write-Verbose "Searching $($sheet.Cells.Item(1, $column).Text) for NULL in $($sheet.Name)"
	} else {
		Write-Verbose "Searching $($sheet.Cells.Item(1, $column).Text) for $searchString in $($sheet.Name)"
	}
	$arrFinds = @()
	$intRows = $sheet.cells.Range("A1048576").End($xlup).row
	for ($i = 2; $i -le $intRows; $i++) {
		if ($sheet.Cells.Item($i, $column).Text -eq $searchString) {
			$arrFinds += $i
		}
	}
	if ($arrFinds) {
		if ($searchString -eq '') {
			Write-Output "$($sheet.Cells.Item(1, $column).Text) was set to NULL for the following rows in $($sheet.Name)" | Out-File $outputFile -Append
		} else {
			Write-Output "$($sheet.Cells.Item(1, $column).Text) was set to $searchString for the following rows in $($sheet.Name)" | Out-File $outputFile -Append
		}
		Write-Output $arrFinds | Out-File $outputFile -Append
	}
}

Function Select-SaveFileDialog ($initialDirectory) {
	$SaveFileDialog = New-Object System.Windows.Forms.SaveFileDialog -Property @{
		AddExtension	 = $true;
		DefaultExt	     = '.txt';
		FileName		 = "results.txt";
		Filter		     = 'TXT File|*.txt|All Files|*.*';
		FilterIndex	     = 0;
		InitialDirectory = $initialDirectory;
		Title		     = "Select a txt file";
		ValidateNames    = $true;
	}
	$SaveFileDialog.ShowDialog() | Out-Null
	return $SaveFileDialog.FileName
}
#endregion functions

If (-not $outputFile) {
	$outputFile = Select-SaveFileDialog -initialDirectory "C:\"
}

Write-Output "Starting EPI validation at $(Get-Date)" | Out-File $outputFile -Force

$script:files = Get-ChildItem -Path $testPath -File
foreach ($script:file in $script:files) {
	if ($script:file.Name -match "Asset_Management_EPI_Data_Set_\d{8}.xlsx") {
		$workbook = $excelApplication.Workbooks.Open($script:file.FullName)
		$sheet = Get-Sheet -sheetName 'Asset Management EPI Data Set' -workbook $workbook
		Test-ColumnFormat -sheet $sheet -column 1 -type text
		Test-ColumnFormat -sheet $sheet -column 2 -type text
		Trim-Headers -sheet $sheet
		Find-Duplicates -sheet $sheet -column 1
		Find-Duplicates -sheet $sheet -column 2
		Test-EmailAddresses -sheet $sheet -column 4
		Test-EmailAddresses -sheet $sheet -column 7
		Test-MICode -sheet $sheet
		$excelApplication.ActiveWorkbook.Save()
		$workbook.Close($true)
	} elseif ($script:file.Name -match "Hubzu_EPI_Data_Set_\d{8}.xlsx") {
		$workbook = $excelApplication.Workbooks.Open($script:file.FullName)
		$sheet = Get-Sheet -sheetName 'Hubzu EPI Data Set' -workbook $workbook
		Test-ColumnFormat -sheet $sheet -column 1 -type text
		Test-ColumnFormat -sheet $sheet -column 3 -type text
		Test-ColumnFormat -sheet $sheet -column 5 -type int
		Trim-Headers -sheet $sheet
		Find-Duplicates -sheet $sheet -column 1
		$workbook.Close($true)
	} elseif ($script:file.Name -match "REALResolution_EPI_Data_Set_\d{8}.xlsx") {
		$workbook = $excelApplication.Workbooks.Open($script:file.FullName)
		$sheet = Get-Sheet -sheetName 'REALResolution EPI Data Set' -workbook $workbook
		Test-ColumnFormat -sheet $sheet -column 1 -type text
		Test-ColumnFormat -sheet $sheet -column 6 -type text
		Test-ColumnFormat -sheet $sheet -column 26 -type text
		Test-StringInColumn -sheet $sheet -column 22 -searchString 'REOS/FC'
		$workbook.Close($true)
	} elseif ($script:file.Name -match "Resware_EPI_Data_Set_\d{8}.xlsx") {
		$workbook = $excelApplication.Workbooks.Open($script:file.FullName)
		$sheet = Get-Sheet -sheetName 'Resware EPI Data Set' -workbook $workbook
		Test-ColumnFormat -sheet $sheet -column 1 -type text
		$workbook.Close($true)
	} elseif ($script:file.Name -match "VMS_EPI_Data_Set_\d{8}.xlsx") {
		$workbook = $excelApplication.Workbooks.Open($script:file.FullName)
		$sheet = Get-Sheet -sheetName 'VMS EPI Data Set' -workbook $workbook
		Test-StringInColumn -sheet $sheet -column 3 -searchString ''
		Test-StringInColumn -sheet $sheet -column 38 -searchString ''
		Test-StringInColumn -sheet $sheet -column 50 -searchString ''
		$workbook.Close($true)
	} else {
		Write-Output "$($script:file.Name) is invalid" | Out-File $outputFile -Append
	}
}

Stop-Excel | Out-Null