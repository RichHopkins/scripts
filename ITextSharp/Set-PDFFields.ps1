<#
	.SYNOPSIS
		Uses a CSV file to fill out a PDF's forms then save it out to a new file.
	
	.DESCRIPTION
		Uses a CSV file to fill out a PDF's forms then save it out to a new file.  Use Get-PDFFields.ps1 to create the CSV template to fill out.
	
	.PARAMETER InputPDF
		Path of the PDF that will be filled out.
	
	.PARAMETER OutputPDF
		Path for the newly saved PDF.
	
	.PARAMETER InputCSV
		Path to the CSV with key/values for the forms.
	
	.PARAMETER ITextLibraryPath
		Path to the ITextLibrary DLL.  Defaults to C:\itextsharp.dll
	
	.EXAMPLE
		PS C:\> .\Set-PDFFields.ps1 -InputPDF 'C:\MakeWholeStatement.pdf' -OutputPDF 'C:\output.pdf' -InputCSV 'C:\temp.csv'
	
	.NOTES
		Outputs System.IO.FileInfo on the newly created PDF.
#>

[CmdletBinding()]
[OutputType([System.IO.FileInfo])]
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
	[ValidatePattern('\.pdf$')]
	[ValidateNotNullOrEmpty()]
	[string]$OutputPDF,
	[Parameter(Mandatory = $true)]
	[ValidateScript({
			Test-Path -Path $_ -PathType Leaf
		})]
	[ValidatePattern('\.csv$')]
	[ValidateNotNullOrEmpty()]
	[string]$InputCSV,
	[ValidateScript({
			Test-Path -Path $_ -PathType Leaf
		})]
	[ValidatePattern('\.dll$')]
	[ValidateNotNullOrEmpty()]
	[string]$ITextLibraryPath = "C:\itextsharp.dll"
)

function Save-PdfField {
	[CmdletBinding()]
	param
	(
		[Hashtable]$Fields,
		[string]$InputPdfFilePath,
		[string]$OutputPdfFilePath,
		[string]$ITextSharpLibrary = "C:\itextsharp.dll"
		
	)
	begin {
		$ErrorActionPreference = 'Stop'
		## Load the iTextSharp DLL to do all the heavy-lifting 
		[System.Reflection.Assembly]::LoadFrom("$ITextSharpLibrary") | Out-Null
	}
	process {
		try {
			$reader = New-Object iTextSharp.text.pdf.PdfReader -ArgumentList $InputPdfFilePath
			$stamper = New-Object iTextSharp.text.pdf.PdfStamper($reader, [System.IO.File]::Create($OutputPdfFilePath))
			
			## Apply all hash table elements into the PDF form
			foreach ($j in $Fields.GetEnumerator()) {
				$null = $stamper.AcroFields.SetField($j.Key, $j.Value)
			}
		} catch {
			$PSCmdlet.ThrowTerminatingError($_)
		} finally {
			## Close up shop 
			$stamper.Close()
		}
	}
}

$csvdata = Import-Csv -Path $InputCSV -Header Key, Value
[hashtable]$pdfHash = @{}
ForEach ($row in $csvdata) {
	If ($row.Key -notlike '#*') {
		$pdfHash[$row.Key] = $row.Value
	}
}
Save-PdfField -InputPdfFilePath $InputPDF -OutputPdfFilePath $OutputPDF -Fields $pdfHash -ITextSharpLibrary $ITextLibraryPath
Get-Item -Path $OutputPDF
