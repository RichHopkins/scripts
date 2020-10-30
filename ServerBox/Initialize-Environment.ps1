[CmdletBinding()]
param
(
	[ValidateScript({ $_ -cmatch "Development|DevInt|Alpha|AlphaX7" })]
	[Alias('env')]
	[string]$environment = ""
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

If ($environment -eq "") { Write-Output "You must provide an environment parameter!"; exit 1}

$xPath = "/Configuration/Environment[@Name=`"$environment`"]"
$environmentData = (Get-XMLFile -xmlFile "\\DevOps\Config\EQConfig.xml" | Select-Xml -XPath $xPath).get_node()

$hashSiteData = @{ }
foreach ($server in $environmentData.ColdFusion.Servers.Server) {
	$serverName = $server.Name
	$instanceCount = [convert]::ToInt32($server.instanceCount, 10)
	$serverData = $environmentData.ColdFusion.Servers.Server | Where-Object { $_.Name -eq $serverName }
	$site = $serverData.Website | Where-Object { $_.JSN -eq "True" }
	if ($site) {
		#Create a site - instance list hash
		For ($i = 1; $i -le $instanceCount; $i++) {
			If ($hashSiteData.Keys -notcontains $site.Name) {
				If ($serverName -match "v8cf") {
					$hashSiteData.Add($site.Name, [System.Collections.Generic.List[System.Object]]("$serverName`:cfusion9-$i"))
				} elseif ($serverName -match "v12cf") {
					$hashSiteData.Add($site.Name, [System.Collections.Generic.List[System.Object]]("$serverName`:cfusion$i"))
				}
			} else {
				If ($serverName -match "v8cf") {
					$instanceList = $hashSiteData.Get_Item($site.Name)
					$instanceList.Add("$serverName`:cfusion9-$i")
					$hashSiteData.Set_Item($site.Name, $instanceList)
				} elseif ($serverName -match "v12cf") {
					$instanceList = $hashSiteData.Get_Item($site.Name)
					$instanceList.Add("$serverName`:cfusion$i")
					$hashSiteData.Set_Item($site.Name, $instanceList)
				}
			}
		}
	} else {
		Write-Output "$serverName does not have a site with a JSN!"
	}
}

$hashSiteData.GetEnumerator() | ForEach-Object {
	[string]$site = $_.Key
	$arrInstances = $_.Value

	$i = 1
	Write-Verbose "Starting to initalize $serverName"

	#start hitting the site and reading the JSN.
	do {
		Write-Verbose "Attempt `#$i to reach $site"
		Try {
			$request = Invoke-WebRequest -Uri $site -ErrorAction SilentlyContinue
		} Catch { }
		#If an instance is found, remove it from the array
		if ($request.StatusCode -eq 200) {
			if ($request.Headers.JSN) {
				Try {
					$instanceName = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($request.Headers.JSN))
					Write-Verbose "$site returned from $instanceName"
					$arrInstances.Remove($instanceName) | Out-Null
				} Catch { }
			} else {
				Write-Verbose "$site redirected to offline page, waiting 15 seconds before trying again."
				Start-Sleep -Seconds 5
			}
		} else {
			If ($request.StatusCode) {
				Write-Verbose "$site threw a $($request.StatusCode) error code"
			} else {
				Write-Verbose "Request to $site timed out"
				Start-Sleep -Seconds 5
			}
		}
		$i++
	} until ($arrInstances.Count -eq 0 -or $i -ge 150)

	#if any sites are left in the array after 100 trys, error which instances didn't respond
	If ($arrInstances.Count -eq 0) {
		Write-Output "All instances for $site have been hit!"
	} else {
		Write-Error "Issue with the site $site"
		Write-Output "Unable to reach the following instance for $site`:"
		Write-Output $arrInstances
	}
}

If ($Error -match "Issue with the site") {
	Write-Output "One or more servers are having issues, please review the log for details."
	throw 1
}