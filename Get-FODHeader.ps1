param
(
	[string]$tenant = "Altisource",
	[Parameter(Mandatory = $true)]
	[string]$username,
	[Parameter(Mandatory = $true)]
	[string]$password
)

(New-Object System.Net.WebClient).Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
$apiUrl = "https://api.ams.fortify.com"

$authParams = @{
	scope	     = "api-tenant";
	grant_type   = "password";
	username	 = "$tenant\$username";
	password	 = $password
}

function Get-Token {
	[CmdletBinding()]
	param ()
	
	$auth = Invoke-RestMethod $apiUrl/oauth/token -Method POST -Body $authParams
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$token = $auth.access_token
	$headers.Add("Authorization", "Bearer $token")
	return $headers
}

$headers = Get-Token
return $headers
#$releases = Invoke-RestMethod $apiUrl/api/v3/releases -Method GET -Headers $headers
#Write-Output $releases