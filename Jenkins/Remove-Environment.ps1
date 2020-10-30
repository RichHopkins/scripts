<#
	.SYNOPSIS
		Remove new environment directory structure.
	
	.DESCRIPTION
		Drops sandboxes and deletes the folders.
	
	.PARAMETER path
		Path to delete
	
	.PARAMETER projects
		Hashtable of Project - Variant combinations.
	
	.PARAMETER username
		User ID to connect to Integrity with.  If no username is supplied Integrity attempts to authenticate the user of the PowerShell session.
	
	.PARAMETER password
		Plaintext password used to authentcate $username.  If not supplied the console window will prompt for a password.
		*This breaks automation if not supplied, but works interactively.

	.EXAMPLE
		Remove-Environment -path "D:\Workflow\Environments\DevInt"
		Drops Core, ServiceMart, and Binaries sandboxes (if found) and deletes the directories from disk.
#>
[CmdletBinding()]
param
(
	[Parameter(Mandatory = $true)]
	[ValidateSet('Development', 'DevInt', 'AlphaX7', 'Alpha', IgnoreCase = $False)]
	[string]$environment
)

Import-Module eqDevOps

$configData = Get-XMLFile "\\DevOps\Config\EQConfig.xml"
$JenkinsData = $configData.Configuration.JenkinsData
$IntegrityUser = $JenkinsData.IntegrityData.IntegrityUser
$IntegrityPass = $JenkinsData.IntegrityData.IntegrityPass
$envPath = Join-Path -Path $JenkinsData.WorkflowPaths.Environments -ChildPath $environment
$envData = ($configData | Select-Xml -XPath "/Configuration/Environment[@Name=`"$environment`"]").get_node()

Connect-Integrity -username $IntegrityUser -password $IntegrityPass

$Variants = $envData.BuildData.Variants.SelectNodes("*")
For ($i = 0; $i -lt $Variants.Count; $i++)
{
	Write-Output "Dropping sandbox for project $($Variants[$i].Project.ToString()) - variant $($Variants[$i].Name.ToString())"
	Write-ToSlack -channel "`#devops-$environment" -message "Started at: $(Get-Date -Format g) - Dropping varient $($Variants[$i].Name.ToString()) for the $($Variants[$i].Project.ToString()) project at $(Join-Path -Path $envPath -ChildPath "$($Variants[$i].Project.ToString())")"
	Remove-IntegritySandbox -path "$(Join-Path -Path $envPath -ChildPath "$($Variants[$i].Project.ToString())")" -delete -username $IntegrityUser -password $IntegrityPass
}
& cmd.exe /c "RMDIR /S /Q $envPath"

Disconnect-Integrity -username $IntegrityUser -password $IntegrityPass
Exit-Integrity