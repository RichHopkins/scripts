<#
	.SYNOPSIS
		Splits a larger file into smaller ones
	
	.DESCRIPTION
		Takes the filePath file and splits it in to a default of 100MB size smaller files that go into destinationPath.
	
	.PARAMETER filePath
		Path to the file you want to split up.
	
	.PARAMETER destinationPath
		Destination folder for the new smaller files.  If the path does not exist, it will be created.
	
	.PARAMETER maxSize
		Size for the smaller files.  Default value = 100MB.
	
	.EXAMPLE
		PS C:\> Split-File -filePath "C:\logs\test.log" -destinationPath "C:\newlogs"
		Takes test.log and creates smaller 100MB splits of it in C:\newlogs

	.EXAMPLE
		PS C:\> Split-File -filePath "C:\logs\test.log" -destinationPath "C:\newlogs" -maxSize 5MB
		Takes test.log and creates smaller 5MB splits of it in C:\newlogs
#>
[CmdletBinding()]
param
(
	[Parameter(Mandatory = $true,
			   Position = 0)]
	[ValidateScript({ Test-Path $_ })]
	[string]$filePath,
	[Parameter(Mandatory = $true,
			   Position = 1)]
	[string]$destinationPath,
	[Parameter(Position = 2)]
	[Alias('upperBound')]
	[int]$maxSize = 100MB
)

# Modified from: http://stackoverflow.com/a/11010158/215200

$file = Get-Item $filePath
$arrName = $file.Name -split "\."
$rootName = $arrName[0]
$ext = $arrName[$arrName.Count - 1]

$from = $file.FullName
$fromFile = [io.file]::OpenRead($from)

$buff = new-object byte[] $maxSize

$count = $idx = 0

try {
    "Splitting $from using $maxSize bytes per file."
    do {
        $count = $fromFile.Read($buff, 0, $buff.Length)
        if ($count -gt 0) {
            $to = "{0}\{1}.{2}.{3}" -f ($destinationPath, $rootName, $idx, $ext)
            $toFile = [io.file]::OpenWrite($to)
            try {
                "Writing to $to"
                $tofile.Write($buff, 0, $count)
            } finally {
                $tofile.Close()
            }
        }
        $idx ++
    } while ($count -gt 0)
}
finally {
    $fromFile.Close()
}