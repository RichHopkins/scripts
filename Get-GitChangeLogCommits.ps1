[CmdletBinding()]
param
(
	[Parameter(Mandatory = $true, Position = 0)]
	[ValidateScript({Test-Path $_})]
	[string]$path
)
$arrFiles = @()
$commits = Get-Content -Path $path | Select-String ':\d{6}'
foreach ($commit in ($commits -split " M`t")) {
	If ($commit -notmatch ':') {
		$arrFiles += $commit
	}
}
$arrFiles = $arrFiles | Sort-Object -Unique
Write-Output $arrFiles