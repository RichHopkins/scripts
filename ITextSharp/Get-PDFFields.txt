<#
	.SYNOPSIS
		Gets the list of form fields from a given PDF and creates a CSV from them
	
	.DESCRIPTION
		Gets the list of form fields from a given PDF and creates a CSV from them.  The CSV values can then be filled out and consumed by Set-PDFFields.ps1
	
	.PARAMETER InputPDF
		Path of the PDF to scan for form fields.
	
	.PARAMETER OutputCSV
		Path for the CSV to output the list of form fields to.
	
	.PARAMETER ITextLibraryPath
		Path to the ITextLibrary DLL.  Defaults to C:\itextsharp.dll
	
	.EXAMPLE
		PS C:\> .\Get-PDFFields.ps1 -InputPDF 'C:\MakeWholeStatement.pdf' -OutputCSV 'C:\output.csv'
#>

[CmdletBinding()]
param
(
	[Parameter(Mandatory = $true)]
	[ValidateScript({
			Test-Path -Path $_ -PathType Leaf
		})]
	[ValidatePattern('\.pdf$')]
	[ValidateNotNullOrEmpty()]
	[string]$InputPDF,
	[Parameter(Mandatory = $true)]
	[ValidateScript({
			-not (Test-Path -Path $_ -PathType Leaf)
		})]
	[ValidatePattern('\.csv$')]
	[ValidateNotNullOrEmpty()]
	[string]$OutputCSV,
	[ValidateScript({
			Test-Path -Path $_ -PathType Leaf
		})]
	[ValidatePattern('\.dll$')]
	[ValidateNotNullOrEmpty()]
	[string]$ITextLibraryPath = "C:\itextsharp.dll"
)

function Get-PdfFields {
	[OutputType([string[]])]
	[CmdletBinding()]
	param
	(
		[string]$FilePath,
		[string]$ITextLibraryPath = "C:\itextsharp.dll"
	)
	begin {
		$ErrorActionPreference = 'Stop'
		[System.Reflection.Assembly]::LoadFrom($ITextLibraryPath) | Out-Null
	}
	process {
		try {
			$reader = New-Object iTextSharp.text.pdf.PdfReader -ArgumentList $FilePath
			Write-Output $reader.AcroFields.Fields.Key
		} catch {
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}

#Get list of keys
[string[]]$keys = Get-PdfFields -FilePath $InputPDF
[hashtable]$pdfKeyHash = @{
}
#convert keys into a hashtable with null values
foreach ($key in $keys) {
	$pdfKeyHash.Add($key, $null)
}
#export the hashtable to a csv to fill out
$pdfKeyHash.GetEnumerator() | Select-Object Key, Value | Export-Csv -Path $OutputCSV -NoTypeInformation -Force