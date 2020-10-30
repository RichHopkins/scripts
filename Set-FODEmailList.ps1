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
	$auth = Invoke-RestMethod $apiUrl/oauth/token -Method POST -Body $authParams
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$token = $auth.access_token
	$headers.Add("Authorization", "Bearer $token")
	return $headers
}

$body = @{
	applicationName	       = "ASPS Equator V5_Platform _Webapps"
	applicationDescription = "Equator Demo in cold fusion"
	emailList			   = "eqdevops@equator.com,ISDVMP_SecureCodeAssessmentProgram@almridulesh.kumar@altisource.com,Pradeep.Vinitha@equator.com,test@equator.com"
	businessCriticalityTypeId = 1
	businessCriticalityType = "High"
}
$json = $body | ConvertTo-Json

$headers = Get-Token
Invoke-RestMethod $apiUrl/api/v3/applications/84355 -Method PUT -Headers $headers -Body $json -ContentType application/json