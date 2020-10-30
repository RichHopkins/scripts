[CmdletBinding()]
param
(
	[Parameter(Mandatory = $true,
			   Position = 0)]
	[string]$environment
)
switch ($environment) {
	Development {
		$server = "txv8sqeqnc01"
	}
	DevInt {
		$server = "txv8sqeqnc02"
	}
	Alpha {
		$server = "txv8sqeqnq01"
	}
	default {
		throw "Environments not found"
	}
}
$sqlScript = "EXEC proc_upd_Release_Version @ENVIRONMENT_KEY='$environment', @RELEASE_VERSION='10.01.$((get-date -Format o).Replace(":", "."))'"
Import-Module eqDevOps
Invoke-Sqlcmd2 -ServerInstance $server -Database "Environments" -Query $sqlScript -Verbose