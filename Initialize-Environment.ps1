[CmdletBinding()]
param
(
	[ValidateScript({ $_ -cmatch "Development|DevInt|Alpha|AlphaX7" })]
	[Alias('env')]
	[string]$environment = ""
)

If ($environment -eq "") { Write-Output "You must provide an environment parameter!"; exit}

$xPath = "/Configuration/Environment[@Name=`"$environment`"]"
$environmentData = (Get-XMLFile -xmlFile "\\DevOps\Config\EQConfig.xml" | Select-Xml -XPath $xPath).get_node()

$hashSiteData = @{ }
foreach ($server in $environmentData.ColdFusion.Servers.Server) {
	$serverName = $server.Name
	$instanceCount = [convert]::ToInt32($server.instanceCount, 10)
	$serverData = $environmentData.ColdFusion.Servers.Server | Where-Object { $_.Name -eq $serverName }
	$site = $serverData.Website | Where-Object { $_.JSN -eq "True" }
	For ($i = 1; $i -le $instanceCount; $i++) {
		If ($hashSiteData.Keys -notcontains $site.Name) {
			If ($serverName -match "v8") {
				$hashSiteData.Add($site.Name, [System.Collections.Generic.List[System.Object]]("$serverName`:cfusion9-$i"))
			} elseif ($serverName -match "v12") {
				$hashSiteData.Add($site.Name, [System.Collections.Generic.List[System.Object]]("$serverName`:cfusion$i"))
			}
		} else {
			If ($serverName -match "v8") {
				$instanceList = $hashSiteData.Get_Item($site.Name)
				$instanceList.Add("$serverName`:cfusion9-$i")
				$hashSiteData.Set_Item($site.Name, $instanceList)
			} elseif ($serverName -match "v12") {
				$instanceList = $hashSiteData.Get_Item($site.Name)
				$instanceList.Add("$serverName`:cfusion$i")
				$hashSiteData.Set_Item($site.Name, $instanceList)
			}
		}
	}
}

$hashSiteData.GetEnumerator() | ForEach-Object {
	$site = $_.Key
	$arrInstances = $_.Value
	$i = 1
	do {
		Write-Output "Attempt `#$i to reach $site"
		Try {
			$request = Invoke-WebRequest -Uri $site -ErrorAction SilentlyContinue
		} Catch { }
		if ($request.StatusCode -eq 200) {
			if ($request.Headers.JSN) {
				Try {
					$base64 = $request.Headers.JSN -replace "==", ""
					$instanceName = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($request.Headers.JSN))
					Write-Output "$site returned from $instanceName"
					$arrInstances.Remove($instanceName) | Out-Null
				} Catch { }
			} else {
				Write-Output "$site redirected to offline page, waiting 15 seconds before trying again."
				Start-Sleep -Seconds 15
			}
		} else {
			Write-Output "$site threw a $($request.StatusCode) error code"
		}
		$i++
	} until ($arrInstances.Count -eq 0 -or $i -ge 50)
	If ($i -lt 50) {
		Write-Output "All instances for $site have been hit"
	} else {
		Write-Output "Unable to reach the following instance for $site`:"
		Write-Output $arrInstances
	}
}
