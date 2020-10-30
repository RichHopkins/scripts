<#
	.SYNOPSIS
		Used to search a list of directories looking for a string in the path
	
	.DESCRIPTION
		You can either pass a param of -testFile with a path to a list of vendors or clients to search for, or use -testStrings to pass in a pre-populated array.
	
	.PARAMETER path
		Path to the directories to search through
	
	.PARAMETER log
		Path to the log file.
	
	.PARAMETER testStrings
		Array of string to look for within the search directories paths.
	
	.PARAMETER testFile
		Path to a file with a list of strings to search directories paths for.
	
	.EXAMPLE
		PS C:\> .\Find-StringinDirs.ps1 -testStrings $arrStrings -path "C:\path\to\variant" -log "C:\results.txt"
		PS C:\> .\Find-StringinDirs.ps1 -testFile "C:\LenderList" -path "C:\path\to\variant" -log "C:\results.txt"
#>
[CmdletBinding()]
param
(
	[Parameter(Mandatory = $true)]
	[ValidateScript({
			Test-Path -Path $_
		})]
	[Alias('dir')]
	[string]$path,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[Alias('logPath', 'logFile')]
	[string]$log,
	[Parameter(ParameterSetName = 'testStrings',
			   Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[Alias('strings')]
	[array]$testStrings,
	[Parameter(ParameterSetName = 'testFile',
			   Mandatory = $true)]
	[ValidateScript({
			Test-Path -Path $_
		})]
	[string]$testFile
)

$dirs = Get-ChildItem -Path $path -Recurse -Force -Directory
if ($PSCmdlet.ParameterSetName -eq 'testFile') {
	$strings = @(Get-Content $testFile)
} else {
	$strings = $testStrings
}
if (Test-Path $log) {
	Remove-Item $log -Force
} elseif (-not (Test-Path (Split-Path -Path $log -Parent))) {
	New-Item -Path (Split-Path -Path $log -Parent) -ItemType directory
}
foreach ($dir in $dirs.FullName) {
	foreach ($str in $strings) {
		if ($dir -match $str) {
			Write-Output $dir | Out-File $log -Append
		}
	}
}
