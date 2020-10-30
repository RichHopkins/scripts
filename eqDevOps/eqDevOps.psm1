<#	
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2017 v5.4.134
	 Created on:   	1/24/2017 5:44 AM
	 Created by:   	Rich Hopkins
	 Organization: 	Equator
	 Filename:     	eqDevOps.psm1
	-------------------------------------------------------------------------
	 Module Name: eqDevOps
	===========================================================================
#>

function Split-File {
<#
	.SYNOPSIS
		Splits a larger file into smaller ones
	
	.DESCRIPTION
		Takes the filePath file and splits it in to a default of 100MB size smaller files that go into destinationPath.
	
	.PARAMETER filePath
		Path to the file you want to split up.
	
	.PARAMETER destinationPath
		Destination folder for the new smaller files.  If the path does not exist, it will be created.
	
	.PARAMETER maxSize
		Size for the smaller files.  Default value = 100MB.
	
	.EXAMPLE
		PS C:\> Split-File -filePath "C:\logs\test.log" -destinationPath "C:\newlogs"
		Takes test.log and creates smaller 100MB splits of it in C:\newlogs

	.EXAMPLE
		PS C:\> Split-File -filePath "C:\logs\test.log" -destinationPath "C:\newlogs" -maxSize 5MB
		Takes test.log and creates smaller 5MB splits of it in C:\newlogs
#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true,
				   Position = 0)]
		[ValidateScript({
				Test-Path $_
			})]
		[string]$filePath,
		[Parameter(Mandatory = $true,
				   Position = 1)]
		[string]$destinationPath,
		[Parameter(Position = 2)]
		[Alias('upperBound')]
		[int]$maxSize = 100MB
	)
	
	# Modified from: http://stackoverflow.com/a/11010158/215200
	
	$file = Get-Item $filePath
	$arrName = $file.Name -split "\."
	$rootName = $arrName[0]
	$ext = $arrName[$arrName.Count - 1]
	
	$from = $file.FullName
	$fromFile = [io.file]::OpenRead($from)
	
	$buff = new-object byte[] $maxSize
	
	$count = $idx = 0
	
	try {
		"Splitting $from using $maxSize bytes per file."
		do {
			$count = $fromFile.Read($buff, 0, $buff.Length)
			if ($count -gt 0) {
				$to = "{0}\{1}.{2}.{3}" -f ($destinationPath, $rootName, $idx, $ext)
				$toFile = [io.file]::OpenWrite($to)
				try {
					"Writing to $to"
					$tofile.Write($buff, 0, $count)
				} finally {
					$tofile.Close()
				}
			}
			$idx++
		} while ($count -gt 0)
	} finally {
		$fromFile.Close()
	}
}

function Get-IPList {
<#
	.SYNOPSIS
		Gets list of IPs available for web binding.
	
	.DESCRIPTION
		Queries a computer for all IP addresses, with the exception of the main IP registered to DNS.
	
	.PARAMETER computerName
		Name of the server to query.
	
	.EXAMPLE
		PS C:\> Get-IPList -computerName 'CADEVEA02'
#>
	param
	(
		[string]$computerName = $env:COMPUTERNAME
	)
	
	$hostIP = ([System.Net.Dns]::GetHostAddresses($computerName)).IPAddressToString | Where-Object {
		$_ -ne '::1'
	}
	$ipList = Get-WmiObject Win32_NetworkAdapterConfiguration -ComputerName $computerName | Where-Object {
		$_.IPAddress.length -gt 1
	}
	$ipList = $ipList.IPAddress | Where-Object {
		$_ -ne $hostIP
	}
	Write-Output "Host IP: $hostIP"
	Write-Output "Other IPs:"
	Write-Output $ipList
}

function Get-XMLFile {
<#
	.SYNOPSIS
		Reads an XML file and returns a xml object.
	
	.DESCRIPTION
		Reads an XML file and returns a xml object.
	
	.PARAMETER xmlFile
		Path to the xml file to be read.
	
	.EXAMPLE
		PS C:\> $xmlFile = Get-XMLFile -xmlFile $value1
#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$xmlFile
	)
	[xml]$xmlData = get-content $xmlFile -ErrorAction SilentlyContinue
	return $xmlData
}

function Test-XMLFile {
<#
	.SYNOPSIS
		Validates a XML file against a XSD schema file.
	
	.DESCRIPTION
		Validates a XML file against a XSD schema file.
	
	.PARAMETER XmlFile
		Path to the XML file to validate.
	
	.PARAMETER XSDFile
		Path to the XSD file to validate against.
		
	.EXAMPLE
		PS C:\> Test-XMLFile -XmlFile 'C:\Path\To\the\xml\file.xml' -XSDFile 'C:\Path\To\the\xsd\file.xsd'
	
	.OUTPUTS
		System.Boolean
#>
	[CmdletBinding()]
	[OutputType([bool])]
	param
	(
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $true)]
		[string]$XmlFile,
		[Parameter(Mandatory = $true)]
		[string]$XSDFile,
		[scriptblock]$ValidationEventHandler = {
			Write-Error $args[1].Exception
		}
	)
	
	$xml = New-Object System.Xml.XmlDocument
	$schemaReader = New-Object System.Xml.XmlTextReader $XSDFile
	$schema = [System.Xml.Schema.XmlSchema]::Read($schemaReader, $ValidationEventHandler)
	$xml.Schemas.Add($schema) | Out-Null
	$xml.Load($XmlFile)
	$validate = ($xml.Validate($ValidationEventHandler) 2>&1)
	#The Validate method only returns error info, so I capture it and redirect to StdOut as a string.
	If (!($validate)) {
		Return $true
	} Else {
		#no error found
		Return $false
	}
}

function Set-XMLFile {
<#
	.SYNOPSIS
		Saves $xmlData to $xmlFile path.
	
	.DESCRIPTION
		Saves $xmlData to $xmlFile path using indenting and ensuring UTF8Encoding is False.
	
	.PARAMETER xmlFile
		Path to where the file should be saved.
	
	.PARAMETER xmlData
		XML data to save into the file.
	
	.EXAMPLE
		PS C:\> Save-XMLFile -xmlFile C:\path\to\file.xml -xmlData $someXmlData
#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$xmlFile,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[xml]$xmlData
	)
	#Make sure BOM is not saved in XML file
	$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($False)
	$textWriter = New-Object System.Xml.XmlTextWriter($xmlFile, $Utf8NoBomEncoding)
	$textWriter.Formatting = "indented"
	$textWriter.Indentation = 2
	$xmlData.save($textWriter)
	$textWriter.close()
}

function Show-XMLData {
<#
	.SYNOPSIS
		Displays formatted XML data to the console
	
	.DESCRIPTION
		Displays formatted XML data to the console
	
	.PARAMETER xmlElem
		The XML element to display.
	
	.EXAMPLE
		PS C:\> Show-XMLData -xmlElem $xmlValue
#>
	
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[xml]$xmlElem
	)
	
	$xmlDoc = New-Object System.Xml.XmlDataDocument
	$sw = New-Object System.IO.StringWriter
	$writer = New-Object System.Xml.XmlTextWriter($sw)
	$xmlElem.WriteTo($writer)
	$xmlDoc.LoadXML($sw.ToString())
	$xmlDoc.Save([Console]::Out)
	
	$writer.Formatting = [System.Xml.Formatting]::Indented
	$xmlDoc.WriteContentTo($writer)
	$xmlDoc.Save([Console]::Out)
}

function Install-Chocolatey {
	# For organizational deployments of Chocolatey, please see https://chocolatey.org/docs/how-to-setup-offline-installation
	
	# Environment Variables, specified as $env:NAME in PowerShell.exe and %NAME% in cmd.exe.
	# For explicit proxy, please set $env:chocolateyProxyLocation and optionally $env:chocolateyProxyUser and $env:chocolateyProxyPassword
	# For an explicit version of Chocolatey, please set $env:chocolateyVersion = 'versionnumber'
	# To target a different url for chocolatey.nupkg, please set $env:chocolateyDownloadUrl = 'full url to nupkg file'
	# NOTE: $env:chocolateyDownloadUrl does not work with $env:chocolateyVersion.
	# To use built-in compression instead of 7zip (requires additional download), please set $env:chocolateyUseWindowsCompression = 'true'
	# To bypass the use of any proxy, please set $env:chocolateyIgnoreProxy = 'true'
	
	#specifically use the API to get the latest version (below)
	$url = '\\devops\Scripts\chocolatey.zip'
	
	$chocolateyVersion = $env:chocolateyVersion
	if (![string]::IsNullOrEmpty($chocolateyVersion)) {
		Write-Output "Downloading specific version of Chocolatey: $chocolateyVersion"
		$url = "https://chocolatey.org/api/v2/package/chocolatey/$chocolateyVersion"
	}
	
	$chocolateyDownloadUrl = $env:chocolateyDownloadUrl
	if (![string]::IsNullOrEmpty($chocolateyDownloadUrl)) {
		Write-Output "Downloading Chocolatey from : $chocolateyDownloadUrl"
		$url = "$chocolateyDownloadUrl"
	}
	
	if ($env:TEMP -eq $null) {
		$env:TEMP = Join-Path $env:SystemDrive 'temp'
	}
	$chocTempDir = Join-Path $env:TEMP "chocolatey"
	Get-ChildItem $chocTempDir -Recurse -Force | Where-Object {
		$_.PSIsContainer -ne $true
	} | ForEach-Object {
		Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue -Confirm:$false
	}
	Remove-Item $chocTempDir -Recurse -Force -ErrorAction SilentlyContinue -Confirm:$false
	$tempDir = Join-Path $chocTempDir "chocInstall"
	if (![System.IO.Directory]::Exists($tempDir)) {
		[void][System.IO.Directory]::CreateDirectory($tempDir)
	}
	$file = Join-Path $tempDir "chocolatey.zip"
	
	# PowerShell v2/3 caches the output stream. Then it throws errors due
	# to the FileStream not being what is expected. Fixes "The OS handle's
	# position is not what FileStream expected. Do not use a handle
	# simultaneously in one FileStream and in Win32 code or another
	# FileStream."
	function Fix-PowerShellOutputRedirectionBug {
		$poshMajorVerion = $PSVersionTable.PSVersion.Major
		
		if ($poshMajorVerion -lt 4) {
			try {
				# http://www.leeholmes.com/blog/2008/07/30/workaround-the-os-handles-position-is-not-what-filestream-expected/ plus comments
				$bindingFlags = [Reflection.BindingFlags] "Instance,NonPublic,GetField"
				$objectRef = $host.GetType().GetField("externalHostRef", $bindingFlags).GetValue($host)
				$bindingFlags = [Reflection.BindingFlags] "Instance,NonPublic,GetProperty"
				$consoleHost = $objectRef.GetType().GetProperty("Value", $bindingFlags).GetValue($objectRef, @())
				[void]$consoleHost.GetType().GetProperty("IsStandardOutputRedirected", $bindingFlags).GetValue($consoleHost, @())
				$bindingFlags = [Reflection.BindingFlags] "Instance,NonPublic,GetField"
				$field = $consoleHost.GetType().GetField("standardOutputWriter", $bindingFlags)
				$field.SetValue($consoleHost, [Console]::Out)
				[void]$consoleHost.GetType().GetProperty("IsStandardErrorRedirected", $bindingFlags).GetValue($consoleHost, @())
				$field2 = $consoleHost.GetType().GetField("standardErrorWriter", $bindingFlags)
				$field2.SetValue($consoleHost, [Console]::Error)
			} catch {
				Write-Output "Unable to apply redirection fix."
			}
		}
	}
	
	Fix-PowerShellOutputRedirectionBug
	
	# Attempt to set highest encryption available for SecurityProtocol.
	# PowerShell will not set this by default (until maybe .NET 4.6.x). This
	# will typically produce a message for PowerShell v2 (just an info
	# message though)
	try {
		# Set TLS 1.2 (3072), then TLS 1.1 (768), then TLS 1.0 (192), finally SSL 3.0 (48)
		# Use integers because the enumeration values for TLS 1.2 and TLS 1.1 won't
		# exist in .NET 4.0, even though they are addressable if .NET 4.5+ is
		# installed (.NET 4.5 is an in-place upgrade).
		[System.Net.ServicePointManager]::SecurityProtocol = 3072 -bor 768 -bor 192 -bor 48
	} catch {
		Write-Output 'Unable to set PowerShell to use TLS 1.2 and TLS 1.1 due to old .NET Framework installed. If you see underlying connection closed or trust errors, you may need to do one or more of the following: (1) upgrade to .NET Framework 4.5+ and PowerShell v3, (2) specify internal Chocolatey package location (set $env:chocolateyDownloadUrl prior to install or host the package internally), (3) use the Download + PowerShell method of install. See https://chocolatey.org/install for all install options.'
	}
	
	function Get-Downloader {
		param (
			[string]$url
		)
		
		$downloader = new-object System.Net.WebClient
		
		$defaultCreds = [System.Net.CredentialCache]::DefaultCredentials
		if ($defaultCreds -ne $null) {
			$downloader.Credentials = $defaultCreds
		}
		
		$ignoreProxy = $env:chocolateyIgnoreProxy
		if ($ignoreProxy -ne $null -and $ignoreProxy -eq 'true') {
			Write-Debug "Explicitly bypassing proxy due to user environment variable"
			$downloader.Proxy = [System.Net.GlobalProxySelection]::GetEmptyWebProxy()
		} else {
			# check if a proxy is required
			$explicitProxy = $env:chocolateyProxyLocation
			$explicitProxyUser = $env:chocolateyProxyUser
			$explicitProxyPassword = $env:chocolateyProxyPassword
			if ($explicitProxy -ne $null -and $explicitProxy -ne '') {
				# explicit proxy
				$proxy = New-Object System.Net.WebProxy($explicitProxy, $true)
				if ($explicitProxyPassword -ne $null -and $explicitProxyPassword -ne '') {
					$passwd = ConvertTo-SecureString $explicitProxyPassword -AsPlainText -Force
					$proxy.Credentials = New-Object System.Management.Automation.PSCredential ($explicitProxyUser, $passwd)
				}
				
				Write-Debug "Using explicit proxy server '$explicitProxy'."
				$downloader.Proxy = $proxy
				
			} elseif (!$downloader.Proxy.IsBypassed($url)) {
				# system proxy (pass through)
				$creds = $defaultCreds
				if ($creds -eq $null) {
					Write-Debug "Default credentials were null. Attempting backup method"
					$cred = get-credential
					$creds = $cred.GetNetworkCredential();
				}
				
				$proxyaddress = $downloader.Proxy.GetProxy($url).Authority
				Write-Debug "Using system proxy server '$proxyaddress'."
				$proxy = New-Object System.Net.WebProxy($proxyaddress)
				$proxy.Credentials = $creds
				$downloader.Proxy = $proxy
			}
		}
		
		return $downloader
	}
	
	function Download-String {
		param (
			[string]$url
		)
		$downloader = Get-Downloader $url
		
		return $downloader.DownloadString($url)
	}
	
	function Download-File {
		param (
			[string]$url,
			[string]$file
		)
		#Write-Output "Downloading $url to $file"
		$downloader = Get-Downloader $url
		
		$downloader.DownloadFile($url, $file)
	}
	
	if ($url -eq $null -or $url -eq '') {
		Write-Output "Getting latest version of the Chocolatey package for download."
		$url = 'https://chocolatey.org/api/v2/Packages()?$filter=((Id%20eq%20%27chocolatey%27)%20and%20(not%20IsPrerelease))%20and%20IsLatestVersion'
		[xml]$result = Download-String $url
		$url = $result.feed.entry.content.src
	}
	
	# Download the Chocolatey package
	Write-Output "Getting Chocolatey from $url."
	Download-File $url $file
	
	# Determine unzipping method
	# 7zip is the most compatible so use it by default
	$7zaExe = Join-Path $tempDir '7za.exe'
	$unzipMethod = '7zip'
	$useWindowsCompression = $env:chocolateyUseWindowsCompression
	if ($useWindowsCompression -ne $null -and $useWindowsCompression -eq 'true') {
		Write-Output 'Using built-in compression to unzip'
		$unzipMethod = 'builtin'
	} elseif (-Not (Test-Path ($7zaExe))) {
		Write-Output "Downloading 7-Zip commandline tool prior to extraction."
		# download 7zip
		Download-File 'https://chocolatey.org/7za.exe' "$7zaExe"
	}
	
	# unzip the package
	Write-Output "Extracting $file to $tempDir..."
	if ($unzipMethod -eq '7zip') {
		$params = "x -o`"$tempDir`" -bd -y `"$file`""
		# use more robust Process as compared to Start-Process -Wait (which doesn't
		# wait for the process to finish in PowerShell v3)
		$process = New-Object System.Diagnostics.Process
		$process.StartInfo = New-Object System.Diagnostics.ProcessStartInfo($7zaExe, $params)
		$process.StartInfo.RedirectStandardOutput = $true
		$process.StartInfo.UseShellExecute = $false
		$process.StartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
		$process.Start() | Out-Null
		$process.BeginOutputReadLine()
		$process.WaitForExit()
		$exitCode = $process.ExitCode
		$process.Dispose()
		
		$errorMessage = "Unable to unzip package using 7zip. Perhaps try setting `$env:chocolateyUseWindowsCompression = 'true' and call install again. Error:"
		switch ($exitCode) {
			0 {
				break
			}
			1 {
				throw "$errorMessage Some files could not be extracted"
			}
			2 {
				throw "$errorMessage 7-Zip encountered a fatal error while extracting the files"
			}
			7 {
				throw "$errorMessage 7-Zip command line error"
			}
			8 {
				throw "$errorMessage 7-Zip out of memory"
			}
			255 {
				throw "$errorMessage Extraction cancelled by the user"
			}
			default {
				throw "$errorMessage 7-Zip signalled an unknown error (code $exitCode)"
			}
		}
	} else {
		if ($PSVersionTable.PSVersion.Major -lt 5) {
			try {
				$shellApplication = new-object -com shell.application
				$zipPackage = $shellApplication.NameSpace($file)
				$destinationFolder = $shellApplication.NameSpace($tempDir)
				$destinationFolder.CopyHere($zipPackage.Items(), 0x10)
			} catch {
				throw "Unable to unzip package using built-in compression. Set `$env:chocolateyUseWindowsCompression = 'false' and call install again to use 7zip to unzip. Error: `n $_"
			}
		} else {
			Expand-Archive -Path "$file" -DestinationPath "$tempDir" -Force
		}
	}
	
	# Call chocolatey install
	Write-Output "Installing chocolatey on this machine"
	$toolsFolder = Join-Path $tempDir "tools"
	$chocInstallPS1 = Join-Path $toolsFolder "chocolateyInstall.ps1"
	
	& $chocInstallPS1
	
	Write-Output 'Ensuring chocolatey commands are on the path'
	$chocInstallVariableName = "ChocolateyInstall"
	$chocoPath = [Environment]::GetEnvironmentVariable($chocInstallVariableName)
	if ($chocoPath -eq $null -or $chocoPath -eq '') {
		$chocoPath = "$env:ALLUSERSPROFILE\Chocolatey"
	}
	
	if (!(Test-Path ($chocoPath))) {
		$chocoPath = "$env:SYSTEMDRIVE\ProgramData\Chocolatey"
	}
	
	$chocoExePath = Join-Path $chocoPath 'bin'
	
	if ($($env:Path).ToLower().Contains($($chocoExePath).ToLower()) -eq $false) {
		$env:Path = [Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::Machine);
	}
	
	Write-Output 'Ensuring chocolatey.nupkg is in the lib folder'
	$chocoPkgDir = Join-Path $chocoPath 'lib\chocolatey'
	$nupkg = Join-Path $chocoPkgDir 'chocolatey.nupkg'
	if (![System.IO.Directory]::Exists($chocoPkgDir)) {
		[System.IO.Directory]::CreateDirectory($chocoPkgDir);
	}
	Copy-Item "$file" "$nupkg" -Force -ErrorAction SilentlyContinue
	
	choco source remove -n="chocolatey"
	choco source add -n=nexus -s="https://nexus/repository/nuget-hosted/" -priority=1 -y
}

function Invoke-Maven {
<#
	.SYNOPSIS
		Executes Maven.
	
	.DESCRIPTION
		Assumes Maven is correctly setup in the PATH, as well as JAVA_HOME and M2_HOME variables.
	
	.PARAMETER goal
		Specifies the goals to execute, such as "clean", "install", or "deploy".
	
	.PARAMETER pomPath
		Path to the POM file. Path is validated with Test-Path.
	
	.PARAMETER deployPath
		Path for Maven to deploy to. Path is validated with Test-Path.
	
	.PARAMETER logPath
		Path to write maven log file to. If this parameter is used there is no console output.
	
	.PARAMETER X
		Turn Maven debugging on.
	
	.EXAMPLE
		Invoke-Maven -goal clean -pomPath "C:\Development\Java\Projects\pom.xml"

	.EXAMPLE
		Invoke-Maven -goal install -pomPath "C:\Development\Java\Projects\pom.xml"

	.EXAMPLE
		Invoke-Maven -goal deploy -pomPath "C:\Development\Java\Projects\pom.xml" -deployPath "C:\Development\Builds"
#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[ValidateSet('clean', 'install', 'deploy', IgnoreCase = $true)]
		[string]$goal,
		[Parameter(Mandatory = $true)]
		[ValidateScript({ Test-Path $_ })]
		[string]$pomPath,
		[ValidateScript({ Test-Path $_ })]
		[Alias('url', 'deployUrl')]
		[string]$deployPath,
		[string]$logPath,
		[switch]$X
	)
	
	If ($PSBoundParameters.ContainsKey('logPath') -eq $true) {
		If ($goal -match "deploy") {
			$cmd = "mvn -B -f $pomPath $goal "" -Ddeployment .DeployURL=$deployPath"" -l $logPath"
		} else {
			$cmd = "mvn -B -f $pomPath $goal -l $logPath"
		}
		If ($X) {
			$cmd = "$cmd -X"
}
} else {
	If ($goal -match "deploy") {
		$cmd = "mvn -B -f $pomPath $goal ""-Ddeployment.DeployURL=$deployPath"""
	} else {
		$cmd = "mvn -B -f $pomPath $goal"
	}
	If ($X) {
		$cmd = "$cmd -X"
	}
}

Write-Verbose "Invoke-Expression $cmd"
Invoke-Expression "$cmd"
}

function Get-PropertiesFile {
<#
	.SYNOPSIS
		Creates a hashtable from a .properties or .config file
	
	.DESCRIPTION
		Outputs a hashtable of properties found within a .properties or .config file.
	
	.PARAMETER filePath
		Path to the file
	
	.PARAMETER Path
		Path to the properties file
	
	.EXAMPLE
		PS C:\> Get-PropertiesFile.ps1 -filePath 'C:\JBoss\client.properties'
#>
	[CmdletBinding()]
	[OutputType([hashtable])]
	param
	(
		[Parameter(Mandatory = $true)]
		[ValidateScript({
				Test-Path $_
			})]
		[Alias('Path')]
		[string]$filePath
	)
	
	$Props = ConvertFrom-StringData (Get-Content $filePath -Raw)
	return $Props
}

function Set-PropertiesFile {
<#
	.SYNOPSIS
		Updates a .properties or .config file from a hashtable
	
	.DESCRIPTION
		Compares the current hashtable of the file to the $newProps hashtable and updates values in the properties file.  
		If a new key is added, the property is written to the first line of the properties file.
		If a key is removed, the property will be commented out unless -deleteLines is specified.
	
	.PARAMETER filePath
		Path of the file to update.
	
	.PARAMETER newProps
		The new values to set in the properties file.

	.PARAMETER deleteLines
		Deletes removed items, rather than comment them out.  Defaults to $false.
	
#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[Alias('Path')]
		[ValidateScript({
				Test-Path $_
			})]
		[string]$filePath,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[hashtable]$newProps,
		[switch]$deleteLines
	)
	
	[Hashtable]$oldProps = ConvertFrom-StringData (Get-Content $filePath -Raw)
	
	$newProps.GetEnumerator() | ForEach-Object {
		[string]$Key = $_.key
		[string]$newValue = $_.value
		[string]$oldValue = $oldProps.Item($Key)
		[int]$contentLength = [System.IO.File]::ReadAllText($filePath).Length
		if ($oldProps.ContainsKey($Key)) {
			if (!($oldProps."$Key" -match $newValue)) {
				$content = [System.IO.File]::ReadAllText($filePath).Replace("$Key=$oldValue", "$Key=$newValue")
				[System.IO.File]::WriteAllText($filePath, $content)
			}
		} else {
			$content = [System.IO.File]::ReadAllText($filePath).Insert($contentLength, "$Key=$newValue`n")
			[System.IO.File]::WriteAllText($filePath, $content)
		}
	}
	
	$oldProps.GetEnumerator() | ForEach-Object {
		[string]$Key = $_.key
		[string]$oldValue = $_.value
		if ($deleteLines -eq $false) {
			if (!($newProps.ContainsKey($Key))) {
				$content = [System.IO.File]::ReadAllText($filePath).Replace("$Key=$oldValue", "`#$Key=$oldValue")
				[System.IO.File]::WriteAllText($filePath, $content)
			}
		} else {
			if (!($newProps.ContainsKey($Key))) {
				$content = [System.IO.File]::ReadAllText($filePath).Replace("$Key=$oldValue", "")
				[System.IO.File]::WriteAllText($filePath, $content)
			}
		}
	}
}

function Edit-StringInFile {
<#
	.SYNOPSIS
		Replaces oldString with newString in filePath.
	
	.DESCRIPTION
		Replaces oldString with newString in filePath.
	
	.PARAMETER filePath
		Path of the file to modify
	
	.PARAMETER oldString
		Original string to replace
	
	.PARAMETER newString
		Replace oldString with this string
	
	.EXAMPLE
		PS C:\> Edit-StringInFile -filePath '$Path' -oldString 'Value1' -newString 'Value2'
	
#>
	[CmdletBinding()]
	param
	(
		[ValidateScript({
				Test-Path $_
			})]
		[string]$filePath,
		[ValidateNotNullOrEmpty()]
		[string]$oldString,
		[string]$newString
	)
	
	(Get-Content $filePath).replace($oldString, $newString) | Set-Content $filePath
}

function Convert-XMLToString {
<#
	.SYNOPSIS
		Converts XML into a string
	
	.DESCRIPTION
		Takes a XmlDocument and converts it into a string.
	
	.PARAMETER xml
		XmlDocument to convert.
	
	.PARAMETER indent
		How much space to use when formatting indented.  If 0 is specified, the xml string will return on a single line.
#>
	[OutputType([string])]
	param
	(
		[xml]$xml,
		[int]$indent = 2
	)
	
	$StringWriter = New-Object System.IO.StringWriter
	$XmlWriter = New-Object System.XMl.XmlTextWriter $StringWriter
	if ($indent -gt 0) {
		$xmlWriter.Formatting = "indented"
		$xmlWriter.Indentation = $Indent
	}
	$xml.WriteContentTo($XmlWriter)
	$XmlWriter.Flush()
	$StringWriter.Flush()
	return $StringWriter.ToString()
}

function Invoke-Sqlcmd2 {
    <#
    .SYNOPSIS
        Runs a T-SQL script.

    .DESCRIPTION
        Runs a T-SQL script. Invoke-Sqlcmd2 runs the whole scipt and only captures the first selected result set, such as the output of PRINT statements when -verbose parameter is specified.
        Paramaterized queries are supported.

        Help details below borrowed from Invoke-Sqlcmd

    .PARAMETER ServerInstance
        One or more ServerInstances to query. For default instances, only specify the computer name: "MyComputer". For named instances, use the format "ComputerName\InstanceName".

    .PARAMETER Database
        A character string specifying the name of a database. Invoke-Sqlcmd2 connects to this database in the instance that is specified in -ServerInstance.

        If a SQLConnection is provided, we explicitly switch to this database

    .PARAMETER Query
        Specifies one or more queries to be run. The queries can be Transact-SQL (? or XQuery statements, or sqlcmd commands. Multiple queries separated by a semicolon can be specified. Do not specify the sqlcmd GO separator. Escape any double quotation marks included in the string ?). Consider using bracketed identifiers such as [MyTable] instead of quoted identifiers such as "MyTable".

    .PARAMETER InputFile
        Specifies a file to be used as the query input to Invoke-Sqlcmd2. The file can contain Transact-SQL statements, (? XQuery statements, and sqlcmd commands and scripting variables ?). Specify the full path to the file.

    .PARAMETER Credential
        Specifies A PSCredential for SQL Server Authentication connection to an instance of the Database Engine.

        If -Credential is not specified, Invoke-Sqlcmd attempts a Windows Authentication connection using the Windows account running the PowerShell session.

        SECURITY NOTE: If you use the -Debug switch, the connectionstring including plain text password will be sent to the debug stream.

    .PARAMETER Encrypt
        If specified, will request that the connection to the SQL is done over SSL. This requires that the SQL Server has been set up to accept SSL requests. For information regarding setting up SSL on SQL Server, visit this link: https://technet.microsoft.com/en-us/library/ms189067(v=sql.105).aspx

    .PARAMETER QueryTimeout
        Specifies the number of seconds before the queries time out.

    .PARAMETER ConnectionTimeout
        Specifies the number of seconds when Invoke-Sqlcmd2 times out if it cannot successfully connect to an instance of the Database Engine. The timeout value must be an integer between 0 and 65534. If 0 is specified, connection attempts do not time out.

    .PARAMETER As
        Specifies output type - DataSet, DataTable, array of DataRow, PSObject or Single Value

        PSObject output introduces overhead but adds flexibility for working with results: http://powershell.org/wp/forums/topic/dealing-with-dbnull/

    .PARAMETER SqlParameters
        Hashtable of parameters for parameterized SQL queries.  http://blog.codinghorror.com/give-me-parameterized-sql-or-give-me-death/

        Example:
            -Query "SELECT ServerName FROM tblServerInfo WHERE ServerName LIKE @ServerName"
            -SqlParameters @{"ServerName = "c-is-hyperv-1"}

    .PARAMETER AppendServerInstance
        If specified, append the server instance to PSObject and DataRow output

    .PARAMETER SQLConnection
        If specified, use an existing SQLConnection.
            We attempt to open this connection if it is closed

    .INPUTS
        None
            You cannot pipe objects to Invoke-Sqlcmd2

    .OUTPUTS
       As PSObject:     System.Management.Automation.PSCustomObject
       As DataRow:      System.Data.DataRow
       As DataTable:    System.Data.DataTable
       As DataSet:      System.Data.DataTableCollectionSystem.Data.DataSet
       As SingleValue:  Dependent on data type in first column.

    .EXAMPLE
        Invoke-Sqlcmd2 -ServerInstance "MyComputer\MyInstance" -Query "SELECT login_time AS 'StartTime' FROM sysprocesses WHERE spid = 1"

        This example connects to a named instance of the Database Engine on a computer and runs a basic T-SQL query.
        StartTime
        -----------
        2010-08-12 21:21:03.593

    .EXAMPLE
        Invoke-Sqlcmd2 -ServerInstance "MyComputer\MyInstance" -InputFile "C:\MyFolder\tsqlscript.sql" | Out-File -filePath "C:\MyFolder\tsqlscript.rpt"

        This example reads a file containing T-SQL statements, runs the file, and writes the output to another file.

    .EXAMPLE
        Invoke-Sqlcmd2  -ServerInstance "MyComputer\MyInstance" -Query "PRINT 'hello world'" -Verbose

        This example uses the PowerShell -Verbose parameter to return the message output of the PRINT command.
        VERBOSE: hello world

    .EXAMPLE
        Invoke-Sqlcmd2 -ServerInstance MyServer\MyInstance -Query "SELECT ServerName, VCNumCPU FROM tblServerInfo" -as PSObject | ?{$_.VCNumCPU -gt 8}
        Invoke-Sqlcmd2 -ServerInstance MyServer\MyInstance -Query "SELECT ServerName, VCNumCPU FROM tblServerInfo" -as PSObject | ?{$_.VCNumCPU}

        This example uses the PSObject output type to allow more flexibility when working with results.

        If we used DataRow rather than PSObject, we would see the following behavior:
            Each row where VCNumCPU does not exist would produce an error in the first example
            Results would include rows where VCNumCPU has DBNull value in the second example

    .EXAMPLE
        'Instance1', 'Server1/Instance1', 'Server2' | Invoke-Sqlcmd2 -query "Sp_databases" -as psobject -AppendServerInstance

        This example lists databases for each instance.  It includes a column for the ServerInstance in question.
            DATABASE_NAME          DATABASE_SIZE REMARKS        ServerInstance
            -------------          ------------- -------        --------------
            REDACTED                       88320                Instance1
            master                         17920                Instance1
            ...
            msdb                          618112                Server1/Instance1
            tempdb                        563200                Server1/Instance1
            ...
            OperationsManager           20480000                Server2

    .EXAMPLE
        #Construct a query using SQL parameters
            $Query = "SELECT ServerName, VCServerClass, VCServerContact FROM tblServerInfo WHERE VCServerContact LIKE @VCServerContact AND VCServerClass LIKE @VCServerClass"

        #Run the query, specifying values for SQL parameters
            Invoke-Sqlcmd2 -ServerInstance SomeServer\NamedInstance -Database ServerDB -query $query -SqlParameters @{ VCServerContact="%cookiemonster%"; VCServerClass="Prod" }

            ServerName    VCServerClass VCServerContact
            ----------    ------------- ---------------
            SomeServer1   Prod          cookiemonster, blah
            SomeServer2   Prod          cookiemonster
            SomeServer3   Prod          blah, cookiemonster

    .EXAMPLE
        Invoke-Sqlcmd2 -SQLConnection $Conn -Query "SELECT login_time AS 'StartTime' FROM sysprocesses WHERE spid = 1"

        This example uses an existing SQLConnection and runs a basic T-SQL query against it

        StartTime
        -----------
        2010-08-12 21:21:03.593


    .NOTES
        Version History
        poshcode.org - http://poshcode.org/4967
        v1.0         - Chad Miller - Initial release
        v1.1         - Chad Miller - Fixed Issue with connection closing
        v1.2         - Chad Miller - Added inputfile, SQL auth support, connectiontimeout and output message handling. Updated help documentation
        v1.3         - Chad Miller - Added As parameter to control DataSet, DataTable or array of DataRow Output type
        v1.4         - Justin Dearing <zippy1981 _at_ gmail.com> - Added the ability to pass parameters to the query.
        v1.4.1       - Paul Bryson <atamido _at_ gmail.com> - Added fix to check for null values in parameterized queries and replace with [DBNull]
        v1.5         - Joel Bennett - add SingleValue output option
        v1.5.1       - RamblingCookieMonster - Added ParameterSets, set Query and InputFile to mandatory
        v1.5.2       - RamblingCookieMonster - Added DBNullToNull switch and code from Dave Wyatt. Added parameters to comment based help (need someone with SQL expertise to verify these)

        github.com   - https://github.com/RamblingCookieMonster/PowerShell
        v1.5.3       - RamblingCookieMonster - Replaced DBNullToNull param with PSObject Output option. Added credential support. Added pipeline support for ServerInstance.  Added to GitHub
                                             - Added AppendServerInstance switch.
                                             - Updated OutputType attribute, comment based help, parameter attributes (thanks supersobbie), removed username/password params
                                             - Added help for sqlparameter parameter.
                                             - Added ErrorAction SilentlyContinue handling to Fill method
        v1.6.0                               - Added SQLConnection parameter and handling.  Is there a more efficient way to handle the parameter sets?
                                             - Fixed SQLConnection handling so that it is not closed (we now only close connections we create)
        v1.6.1       - Shiyang Qiu           - Fixed the verbose option and SQL error handling conflict 
        v1.6.2       - Shiyang Qiu           - Fixed the .DESCRIPTION.
                                             - Fixed the non SQL error handling and added Finally Block to close connection.

    .LINK
        https://github.com/RamblingCookieMonster/PowerShell

    .LINK
        New-SQLConnection

    .LINK
        Invoke-SQLBulkCopy

    .LINK
        Out-DataTable

    .FUNCTIONALITY
        SQL
    #>
	
	[CmdletBinding(DefaultParameterSetName = 'Ins-Que')]
	[OutputType([System.Management.Automation.PSCustomObject], [System.Data.DataRow], [System.Data.DataTable], [System.Data.DataTableCollection], [System.Data.DataSet])]
	param (
		[Parameter(ParameterSetName = 'Ins-Que',
				   Position = 0,
				   Mandatory = $true,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   ValueFromRemainingArguments = $false,
				   HelpMessage = 'SQL Server Instance required...')]
		[Parameter(ParameterSetName = 'Ins-Fil',
				   Position = 0,
				   Mandatory = $true,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   ValueFromRemainingArguments = $false,
				   HelpMessage = 'SQL Server Instance required...')]
		[Alias('Instance', 'Instances', 'ComputerName', 'Server', 'Servers')]
		[ValidateNotNullOrEmpty()]
		[string[]]$ServerInstance,
		[Parameter(Position = 1,
				   Mandatory = $false,
				   ValueFromPipelineByPropertyName = $true,
				   ValueFromRemainingArguments = $false)]
		[string]$Database,
		[Parameter(ParameterSetName = 'Ins-Que',
				   Position = 2,
				   Mandatory = $true,
				   ValueFromPipelineByPropertyName = $true,
				   ValueFromRemainingArguments = $false)]
		[Parameter(ParameterSetName = 'Con-Que',
				   Position = 2,
				   Mandatory = $true,
				   ValueFromPipelineByPropertyName = $true,
				   ValueFromRemainingArguments = $false)]
		[string]$Query,
		[Parameter(ParameterSetName = 'Ins-Fil',
				   Position = 2,
				   Mandatory = $true,
				   ValueFromPipelineByPropertyName = $true,
				   ValueFromRemainingArguments = $false)]
		[Parameter(ParameterSetName = 'Con-Fil',
				   Position = 2,
				   Mandatory = $true,
				   ValueFromPipelineByPropertyName = $true,
				   ValueFromRemainingArguments = $false)]
		[ValidateScript({
				Test-Path $_
			})]
		[string]$InputFile,
		[Parameter(ParameterSetName = 'Ins-Que',
				   Position = 3,
				   Mandatory = $false,
				   ValueFromPipelineByPropertyName = $true,
				   ValueFromRemainingArguments = $false)]
		[Parameter(ParameterSetName = 'Ins-Fil',
				   Position = 3,
				   Mandatory = $false,
				   ValueFromPipelineByPropertyName = $true,
				   ValueFromRemainingArguments = $false)]
		[System.Management.Automation.PSCredential]$Credential,
		[Parameter(ParameterSetName = 'Ins-Que',
				   Position = 4,
				   Mandatory = $false,
				   ValueFromRemainingArguments = $false)]
		[Parameter(ParameterSetName = 'Ins-Fil',
				   Position = 4,
				   Mandatory = $false,
				   ValueFromRemainingArguments = $false)]
		[switch]$Encrypt,
		[Parameter(Position = 5,
				   Mandatory = $false,
				   ValueFromPipelineByPropertyName = $true,
				   ValueFromRemainingArguments = $false)]
		[Int32]$QueryTimeout = 600,
		[Parameter(ParameterSetName = 'Ins-Fil',
				   Position = 6,
				   Mandatory = $false,
				   ValueFromPipelineByPropertyName = $true,
				   ValueFromRemainingArguments = $false)]
		[Parameter(ParameterSetName = 'Ins-Que',
				   Position = 6,
				   Mandatory = $false,
				   ValueFromPipelineByPropertyName = $true,
				   ValueFromRemainingArguments = $false)]
		[Int32]$ConnectionTimeout = 15,
		[Parameter(Position = 7,
				   Mandatory = $false,
				   ValueFromPipelineByPropertyName = $true,
				   ValueFromRemainingArguments = $false)]
		[ValidateSet("DataSet", "DataTable", "DataRow", "PSObject", "SingleValue")]
		[string]$As = "DataRow",
		[Parameter(Position = 8,
				   Mandatory = $false,
				   ValueFromPipelineByPropertyName = $true,
				   ValueFromRemainingArguments = $false)]
		[System.Collections.IDictionary]$SqlParameters,
		[Parameter(Position = 9,
				   Mandatory = $false)]
		[switch]$AppendServerInstance,
		[Parameter(ParameterSetName = 'Con-Que',
				   Position = 10,
				   Mandatory = $false,
				   ValueFromPipeline = $false,
				   ValueFromPipelineByPropertyName = $false,
				   ValueFromRemainingArguments = $false)]
		[Parameter(ParameterSetName = 'Con-Fil',
				   Position = 10,
				   Mandatory = $false,
				   ValueFromPipeline = $false,
				   ValueFromPipelineByPropertyName = $false,
				   ValueFromRemainingArguments = $false)]
		[Alias('Connection', 'Conn')]
		[ValidateNotNullOrEmpty()]
		[System.Data.SqlClient.SQLConnection]$SQLConnection
	)
	
	Begin {
		if ($InputFile) {
			$filePath = $(Resolve-Path $InputFile).path
			$Query = [System.IO.File]::ReadAllText("$filePath")
		}
		
		Write-Verbose "Running Invoke-Sqlcmd2 with ParameterSet '$($PSCmdlet.ParameterSetName)'.  Performing query '$Query'"
		
		If ($As -eq "PSObject") {
			#This code scrubs DBNulls.  Props to Dave Wyatt
			$cSharp = @'
                using System;
                using System.Data;
                using System.Management.Automation;

                public class DBNullScrubber
                {
                    public static PSObject DataRowToPSObject(DataRow row)
                    {
                        PSObject psObject = new PSObject();

                        if (row != null && (row.RowState & DataRowState.Detached) != DataRowState.Detached)
                        {
                            foreach (DataColumn column in row.Table.Columns)
                            {
                                Object value = null;
                                if (!row.IsNull(column))
                                {
                                    value = row[column];
                                }

                                psObject.Properties.Add(new PSNoteProperty(column.ColumnName, value));
                            }
                        }

                        return psObject;
                    }
                }
'@
			
			Try {
				Add-Type -TypeDefinition $cSharp -ReferencedAssemblies 'System.Data', 'System.Xml' -ErrorAction stop
			} Catch {
				If (-not $_.ToString() -like "*The type name 'DBNullScrubber' already exists*") {
					Write-Warning "Could not load DBNullScrubber.  Defaulting to DataRow output: $_"
					$As = "Datarow"
				}
			}
		}
		
		#Handle existing connections
		if ($PSBoundParameters.ContainsKey('SQLConnection')) {
			if ($SQLConnection.State -notlike "Open") {
				Try {
					Write-Verbose "Opening connection from '$($SQLConnection.State)' state"
					$SQLConnection.Open()
				} Catch {
					Throw $_
				}
			}
			
			if ($Database -and $SQLConnection.Database -notlike $Database) {
				Try {
					Write-Verbose "Changing SQLConnection database from '$($SQLConnection.Database)' to $Database"
					$SQLConnection.ChangeDatabase($Database)
				} Catch {
					Throw "Could not change Connection database '$($SQLConnection.Database)' to $Database`: $_"
				}
			}
			
			if ($SQLConnection.state -like "Open") {
				$ServerInstance = @($SQLConnection.DataSource)
			} else {
				Throw "SQLConnection is not open"
			}
		}
		
	}
	Process {
		foreach ($SQLInstance in $ServerInstance) {
			Write-Verbose "Querying ServerInstance '$SQLInstance'"
			
			if ($PSBoundParameters.Keys -contains "SQLConnection") {
				$Conn = $SQLConnection
			} else {
				if ($Credential) {
					$ConnectionString = "Server={0};Database={1};User ID={2};Password=`"{3}`";Trusted_Connection=False;Connect Timeout={4};Encrypt={5}" -f $SQLInstance, $Database, $Credential.UserName, $Credential.GetNetworkCredential().Password, $ConnectionTimeout, $Encrypt
				} else {
					$ConnectionString = "Server={0};Database={1};Integrated Security=True;Connect Timeout={2};Encrypt={3}" -f $SQLInstance, $Database, $ConnectionTimeout, $Encrypt
				}
				
				$conn = New-Object System.Data.SqlClient.SQLConnection
				$conn.ConnectionString = $ConnectionString
				Write-Debug "ConnectionString $ConnectionString"
				
				Try {
					$conn.Open()
				} Catch {
					Write-Error $_
					continue
				}
			}
			
			#Following EventHandler is used for PRINT and RAISERROR T-SQL statements. Executed when -Verbose parameter specified by caller
			if ($PSBoundParameters.Verbose) {
				$conn.FireInfoMessageEventOnUserErrors = $false # Shiyang, $true will change the SQL exception to information
				$handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] {
					Write-Verbose "$($_)"
				}
				$conn.add_InfoMessage($handler)
			}
			
			$cmd = New-Object system.Data.SqlClient.SqlCommand($Query, $conn)
			$cmd.CommandTimeout = $QueryTimeout
			
			if ($SqlParameters -ne $null) {
				$SqlParameters.GetEnumerator() |
				ForEach-Object {
					If ($_.Value -ne $null) {
						$cmd.Parameters.AddWithValue($_.Key, $_.Value)
					} Else {
						$cmd.Parameters.AddWithValue($_.Key, [DBNull]::Value)
					}
				} > $null
			}
			
			$ds = New-Object system.Data.DataSet
			$da = New-Object system.Data.SqlClient.SqlDataAdapter($cmd)
			
			Try {
				[void]$da.fill($ds)
			} Catch [System.Data.SqlClient.SqlException] # For SQL exception
			{
				$Err = $_
				
				Write-Verbose "Capture SQL Error"
				
				if ($PSBoundParameters.Verbose) {
					Write-Verbose "SQL Error:  $Err"
				} #Shiyang, add the verbose output of exception
				
				switch ($ErrorActionPreference.tostring()) {
					{
						'SilentlyContinue', 'Ignore' -contains $_
					} {
					}
					'Stop' {
						Throw $Err
					}
					'Continue' {
						Throw $Err
					}
					Default {
						Throw $Err
					}
				}
			} Catch # For other exception
{
				Write-Verbose "Capture Other Error"
				
				$Err = $_
				
				if ($PSBoundParameters.Verbose) {
					Write-Verbose "Other Error:  $Err"
				}
				
				switch ($ErrorActionPreference.tostring()) {
					{
						'SilentlyContinue', 'Ignore' -contains $_
					} {
					}
					'Stop' {
						Throw $Err
					}
					'Continue' {
						Throw $Err
					}
					Default {
						Throw $Err
					}
				}
			} Finally {
				#Close the connection
				if (-not $PSBoundParameters.ContainsKey('SQLConnection')) {
					$conn.Close()
				}
			}
			
			if ($AppendServerInstance) {
				#Basics from Chad Miller
				$Column = New-Object Data.DataColumn
				$Column.ColumnName = "ServerInstance"
				$ds.Tables[0].Columns.Add($Column)
				Foreach ($row in $ds.Tables[0]) {
					$row.ServerInstance = $SQLInstance
				}
			}
			
			switch ($As) {
				'DataSet'
				{
					$ds
				}
				'DataTable'
				{
					$ds.Tables
				}
				'DataRow'
				{
					$ds.Tables[0]
				}
				'PSObject'
				{
					#Scrub DBNulls - Provides convenient results you can use comparisons with
					#Introduces overhead (e.g. ~2000 rows w/ ~80 columns went from .15 Seconds to .65 Seconds - depending on your data could be much more!)
					foreach ($row in $ds.Tables[0].Rows) {
						[DBNullScrubber]::DataRowToPSObject($row)
					}
				}
				'SingleValue'
				{
					$ds.Tables[0] | Select-Object -ExpandProperty $ds.Tables[0].Columns[0].ColumnName
				}
			}
		}
	}
} #Invoke-Sqlcmd2

function Get-FileEncoding {
	param ([string]$FilePath)
	
	[byte[]]$byte = get-content -Encoding byte -ReadCount 4 -TotalCount 4 -Path $FilePath
	
	if ($byte[0] -eq 0xef -and $byte[1] -eq 0xbb -and $byte[2] -eq 0xbf) {
		$encoding = 'UTF8'
	} elseif ($byte[0] -eq 0xfe -and $byte[1] -eq 0xff) {
		$encoding = 'BigEndianUnicode'
	} elseif ($byte[0] -eq 0xff -and $byte[1] -eq 0xfe) {
		$encoding = 'Unicode'
	} elseif ($byte[0] -eq 0 -and $byte[1] -eq 0 -and $byte[2] -eq 0xfe -and $byte[3] -eq 0xff) {
		$encoding = 'UTF32'
	} elseif ($byte[0] -eq 0x2b -and $byte[1] -eq 0x2f -and $byte[2] -eq 0x76) {
		$encoding = 'UTF7'
	} else {
		$encoding = 'ASCII'
	}
	return $encoding
}

function Test-IsAdmin {
	[CmdletBinding()]
	[OutputType([bool])]
	$check = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
	return $check
}

Function Invoke-AppInstallation {
	[CmdletBinding()]
	Param
	(
		[String][Parameter(Mandatory = $True, Position = 1)]
		$Computername,
		[String][Parameter(Mandatory = $True, Position = 2)]
		$AppName,
		[ValidateSet("Install", "Uninstall")]
		[String][Parameter(Mandatory = $True, Position = 3)]
		$Method
	)
	
	Begin {
		$Application = (Get-CimInstance -ClassName CCM_Application -Namespace "root\ccm\clientSDK" | Where-Object {$_.Name -like $AppName})
		$Args = @{
			EnforcePreference = [UINT32] 0
			Id			      = "$($Application.id)"
			IsMachineTarget   = $Application.IsMachineTarget
			IsRebootIfNeeded  = $False
			Priority		  = 'High'
			Revision		  = "$($Application.Revision)"
		}
	}
	
	Process {
		Invoke-CimMethod -Namespace "root\ccm\clientSDK" -ClassName CCM_Application -MethodName $Method -Arguments $Args
	}
	
	End {
	}
}

Export-ModuleMember -Function Get-IPList,
					Get-XMLFile,
					Test-XMLFile,
					Set-XMLFile,
					Show-XMLData,
					Install-Chocolatey,
					Invoke-Sqlcmd2,
					Write-ToSlack,
					Invoke-Maven,
					Get-PropertiesFile,
					Set-PropertiesFile,
					Edit-StringInFile,
					Convert-XMLToString,
					Split-File,
					Get-FileEncoding,
					Test-IsAdmin,
					Invoke-AppInstallation