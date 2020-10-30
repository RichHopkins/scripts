param
(
	[Parameter(Mandatory = $true)]
	[string]$tenant = "Altisource",
	[Parameter(Mandatory = $true)]
	[string]$username,
	[Parameter(Mandatory = $true)]
	[string]$password
)

(New-Object System.Net.WebClient).Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
$apiUrl = "https://api.ams.fortify.com"
$tenant = "Altisource"
$username = ""
$password = ''

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
$body = @"
{
  "applicationId": 0,
  "releaseName": "api-test",
  "copyState": false,
  "sdlcStatusType": "Development"
}
"@
Invoke-RestMethod $apiUrl/api/v3/releases -Method POST -Headers $headers -Body $body
