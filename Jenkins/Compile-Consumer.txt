[CmdletBinding()]
param
(
	[Parameter(Mandatory = $true)]
	[ValidateSet('DevInt', 'AlphaX7', IgnoreCase = $False)]
	[string]$environment
)

Import-Module eqDevOps

$configData = Get-XMLFile "\\DevOps\Config\EQConfig.xml"
$envPath = Join-Path -Path $configData.Configuration.JenkinsData.WorkflowPaths.Environments -ChildPath $environment

Write-Output "Running Compile CSS for $environment"
Set-Location "$envPath\core\v5\includes\css\_portal\consumer\css_compiler"
& cmd.exe /c "compile_css.bat"

Write-Output "Running Compile JS for $environment"
Set-Location "$envPath\core\v5\resource\internal\_portal\consumer\compiler"
& cmd.exe /c "compileJs.bat"

Write-Output "Running Minify JS for $environment"
Set-Location "$envPath\core\v5\resource\internal\_portal\consumer\minifier"
& cmd.exe /c "minifyJs.bat"