param
(
	[Parameter(Mandatory = $true)]
	[string]$username,
	[Parameter(Mandatory = $true)]
	[string]$password,
	[Parameter(Mandatory = $true)]
	[string]$oldReleaseVersion,
	[Parameter(Mandatory = $true)]
	[string]$newReleaseVersion,
	[string]$jobPath = "\\txv12doeqnc01\d$\jenkins\jobs",
	[string]$tenant = "Altisource",
	[string]$apiBaseUrl = "https://api.ams.fortify.com"
)

$oldReleaseVersion = "13.05"
$newReleaseVersion = "13.06"
$tenant = "Altisource"
$username = ""
$password = ''
$apiBaseUrl = "https://api.ams.fortify.com"
$jobPath = "\\txv12doeqnc01\d$\jenkins\jobs"

(New-Object System.Net.WebClient).Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

$authParams = @{
	scope	     = "api-tenant";
	grant_type   = "password";
	username	 = "$tenant\$username";
	password	 = $password
}

function Get-Token {
	$auth = Invoke-RestMethod $apiBaseUrl/oauth/token -Method POST -Body $authParams
	$header = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$token = $auth.access_token
	$header.Add("Authorization", "Bearer $token")
	return $header
}

#Get list of releases
$header = Get-Token
$releases = Invoke-RestMethod $apiBaseUrl/api/v3/releases -Method GET -Headers $header
$ApplicationId = $releases.items.applicationId | Select-Object -Unique

foreach ($release in $releases.items) {
	if ($release.releaseName -match $oldReleaseVersion -and $release.releaseName -ne "13.05--Global") {
		$oldReleaseName = $release.releaseName
		$oldReleaseId = $release.releaseId
		#region Create New Release
		$newReleaseName = $oldReleaseName.replace($oldReleaseVersion, $newReleaseVersion).replace('-', '_')
		$body = @"
{
  "ApplicationId": $ApplicationId,
  "ReleaseName": "$newReleaseName",
  "copyState": true,
  "copyStateReleaseId": $oldReleaseId,
  "SDLCStatusType": "Development"
}
"@
		$header = Get-Token
		$header.Add("Content-Type", "application/json")
		$header.Add("Accept", "application/json")
		Write-Output "Using $oldReleaseName to create $newReleaseName"
		$newRelease = Invoke-RestMethod $apiBaseUrl/api/v3/releases -Method POST -Headers $header -Body $body
		#endregion Create New Release
		#region Setup Scan Details
		$newReleaseId = $newRelease.releaseId
		$header = Get-Token
		$header.Add("Accept", "application/json")
		$assessmentTypes = Invoke-RestMethod $apiBaseUrl/api/v3/releases/$newReleaseId/assessment-types?scanType=Static -Headers $header
		$assessmentTypeId = $assessmentTypes.items.assessmentTypeId
		$body = @"
{
  "assessmentTypeId": $assessmentTypeId,
  "entitlementFrequencyType": "Subscription",
  "technologyStackId": 5,
  "performOpenSourceAnalysis": false,
  "auditPreferenceType": "Automated",
  "includeThirdPartyLibraries": false,
  "useSourceControl": false
}
"@
		$header = Get-Token
		$header.Add("Content-Type", "application/json")
		$header.Add("Accept", "application/json")
		$bsiGet = Invoke-RestMethod $apiBaseUrl/api/v3/releases/$newReleaseId/static-scans/scan-setup -Method PUT -Headers $header -Body $body
		$bsiGet.bsiToken
		#endregion Setup Scan Details
		#Get BSI Token
		$header = Get-Token
		$header.Add("Accept", "application/json")
		$bsiGet = Invoke-RestMethod $apiBaseUrl/api/v3/releases/$newReleaseId/static-scan-bsi-token -Method GET -Headers $header
		$bsiToken = $bsiGet.bsiToken
		#Setup Jenkins Job
		$clientName = $oldReleaseName.Replace("$oldReleaseVersion-", "")
		$config = [System.IO.File]::ReadAllText("$jobPath\Fortify $clientName Test\config.xml")
		$config = $config -replace "<bsiTokenOriginal>.*</bsiTokenOriginal>", "<bsiTokenOriginal>$bsiToken</bsiTokenOriginal>"
		[System.IO.File]::WriteAllText("$jobPath\config.xml", $config)
		Start-Sleep -Seconds 30
	}
}

#change codebase to new version
Set-Location "\\txv12doeqnc02\d$\Fortify"
git pull
git checkout release/$newReleaseVersion