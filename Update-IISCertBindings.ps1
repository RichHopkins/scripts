param
(
	[string]$certThumbprint
)

Import-Module WebAdministration
$allSites = Get-Website
foreach ($site in $allSites)
{
	$siteName = $site.Name
	$binding = Get-WebBinding -Name $siteName -Protocol "https"
	$binding.AddSslCertificate($certThumbprint, "my")
}

