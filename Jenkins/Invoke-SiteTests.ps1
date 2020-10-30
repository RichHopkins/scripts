[CmdletBinding()]
param
(
	[Parameter(Mandatory = $true)]
	[ValidateSet('Development', 'DevInt', 'AlphaX7', 'Alpha', IgnoreCase = $false)]
	[string]$environment,
	[ValidateRange(0, 10)]
	[int]$retries = 3
)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Import-Module eqDevOps
$xPath = "/Environment[@Name=`"$environment`"]"
#for testing: "C:\configfiles\$($environment)Config.xml"
$envData = (Get-XMLFile -xmlFile "\\DevOps\Config\$($environment)Config.xml" | Select-Xml -XPath $xPath).get_node()
$URIs = @()
foreach ($URI in $envData.ColdFusion.Servers.Server.Website) { $URIs += $URI.Name.ToString() }
$errorURIs = @()
$errorCount = 0

ForEach ($URI in $URIs) {
	If (-not ($URI -match "images" -or $URI -match "webservices")) {
		$iRetry = 0
		$complete = $false
		while ($complete -eq $false) {
			$iRetry++
			Try {
				Write-Output "Trying $URI..."
				$request = Invoke-WebRequest -Uri $URI
				$complete = $true
			} Catch {
				if ($iRetry -gt $retries) {
					$errorURIs += $URI
					$errorCount++
					Write-Output $_.Exception.Message
					Write-Output $_.Exception.Response.StatusDescription
					Write-Output "$URI is offline!"
					Write-Output " "
					$complete = $true
				} else {
					Write-Verbose $_.Exception.Message
					Write-Verbose "Retrying $URI..."
				}
			}
		}
	}
}

If ($errorCount -gt 0) {
	If ($environment -eq "Development") {
		$channel = '#devops-devagl'
	} else {
		$channel = "`#devops-$environment"
	}
	#Write-ToSlack -Channel $channel -Message "The following sites are offline:"
	foreach ($errorURI in $errorURIs) {
		#Write-ToSlack -Channel $channel -Message "$errorURI"
	}
	Send-MailMessage -SmtpServer 'smtp-dev' -To "_COE.EntArch.DevOps@equator.com" -From "eqDevOps <_COE.EntArch.DevOps@equator.com>" -Subject "Site Test Failure - $environment" -Body "$errorURIs"
} else {
	Write-Output "All $environment sites are online."
}