<#
	.SYNOPSIS
		Converts a .json file to .xlsx format
	
	.DESCRIPTION
		Inputs the .json
	
	.PARAMETER source
		The .json file to convert
	
	.PARAMETER destination
		Path of the Excel output
	
	.PARAMETER jsonPath
		The json path to convert
	
	.EXAMPLE
		PS C:\> ConvertFrom-JSONtoExcel.ps1 -source '.\report.json' -destination '.\report.xlsx'
	
	.NOTES
		Additional information about the file.
#>

[CmdletBinding()]
param
(
	[Parameter(Position = 0)]
	[Alias('JSON')]
	[string]$source,
	[Parameter(Position = 1)]
	[Alias('Excel')]
	[string]$destination
)

$inputCSV = "$env:TEMP\report.csv"
$report = (Get-Content $source -Raw | ConvertFrom-Json)
$report.errors | ConvertTo-Csv -NoTypeInformation | Out-File $inputCSV

### Create a new Excel Workbook with one empty sheet which name is the file
$excel = New-Object -ComObject excel.application
$excel.visible = $false
$workbook = $excel.Workbooks.Add(1)
$worksheet = $workbook.worksheets.Item(1)
$worksheet.name = "$((Get-ChildItem $inputCSV).basename)"

### Build the QueryTables.Add command
### QueryTables does the same as when clicking "Data » From Text" in Excel
$TxtConnector = ("TEXT;" + $inputCSV)
$Connector = $worksheet.QueryTables.add($TxtConnector, $worksheet.Range("A1"))
$query = $worksheet.QueryTables.item($Connector.name)

### Set the delimiter ( , or ; ) according to your regional settings
$query.TextFileOtherDelimiter = $Excel.Application.International(5)

### Set the format to delimited and text for every column
### A trick to create an array of 2s is used with the preceding comma
### this options don't seems necessary
$query.TextFileParseType = 1
$query.TextFileColumnDataTypes = ,2 * $worksheet.Cells.Columns.Count
$query.TextFileDecimalSeparator = ","
$query.AdjustColumnWidth = 1

### Execute & delete the import query
# using my_output avoid having an outuput that display true
$my_output = $query.Refresh()
$query.Delete()

### Save & close the Workbook as XLSX.
$Workbook.SaveAs($destination)
$excel.Quit()
Remove-Item $inputCSV -Force