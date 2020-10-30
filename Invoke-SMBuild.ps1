Import-Module eqDevOps
$logPath = "D:\Jenkins\jobs\Test-SMBuild\builds\lastSuccessfulBuild\changeLog.xml"
#$logPath = "C:\changelog2.xml"
$SMRoot = "D:\ServiceMart"
#$SMRoot = "C:\ServiceMart"
[System.Collections.ArrayList]$arrPOMs = @()
[System.Collections.ArrayList]$arrFiles = @()
[System.Collections.ArrayList]$arrBuilds = @()
[System.Collections.ArrayList]$arrBundles = @()

#Read the changeLog.xml and pull out the list of changed files
$commits = Get-Content -Path $logPath | Select-String ':\d{6}'
foreach ($commit in ($commits -split " M`t")) {
	If ($commit -notmatch ':') {
		[void]$arrFiles.Add($commit)
	}
}
if ($arrFiles.Count -gt 1) {
	$arrFiles = $arrFiles | Select-Object -Unique
}
#List of files that changed
#Write-Output $arrFiles

#Find the pom.xml assosiated with the file that changed
foreach ($file in $arrFiles) {
	if ($file -match "pom.xml") {
		$path = ([IO.Path]::Combine("$SMRoot\Fuse", $file)) -replace '/', '\'
		[void]$arrPOMs.Add($path)
	} else {
		[System.Collections.ArrayList]$arrDirs = $file -split '/'
		$arrDirs.RemoveAt($arrDirs.Count - 1)
		for ($x = 0; $x -le ($arrDirs.Count + 1); $x++) {
			$dir = ([IO.Path]::Combine("$SMRoot\Fuse", $arrDirs)) -replace ' ', '\'
			if (Test-Path -Path "$dir\pom.xml") {
				[void]$arrPOMs.Add("$dir\pom.xml")
			} else {
				$arrDirs.RemoveAt($arrDirs.Count - 1)
			}
		}
	}
}
#Remove duplicate entries
if ($arrPOMs.Count -gt 1) {
	$arrPOMs = $arrPOMs | Select-Object -Unique
}
#Write-Output "List of POMs"
#Write-Output $arrPOMs

#Check each pom.xml for a Parent project that should be built instead
for ($i = 0; $i -le ($arrPOMs.Capacity - 1); $i++) {
	$pom = $arrPOMs[$i]
	if ($pom) {
		$xml = Get-XMLFile -xmlFile $pom
		[System.Collections.ArrayList]$arrDirs = $pom -split '\\'
		$arrDirs.RemoveAt($arrDirs.Count - 1)
		$parentArtifactId = $xml.project.parent.artifactId
		$parentRelativePath = $xml.project.parent.relativePath
		if ($parentArtifactId -and $parentArtifactId -ne "SMMavenParent" -and !($parentRelativePath)) {
			$arrDirs.RemoveAt($arrDirs.Count - 1)
			$pomPath = ([IO.Path]::Combine($arrDirs) + "\pom.xml") -replace ":", ":\"
			if (Test-Path $pomPath) {
				[void]$arrBuilds.Add($pomPath)
			}
		} elseif ($parentRelativePath -and $parentArtifactId -ne "SMMavenParent") {
			$removeDirCount = ($parentRelativePath -split "../").Count - 1
			for ($x = 0; $x -le ($removeDirCount - 1); $x++) {
				$arrDirs.RemoveAt($arrDirs.Count - 1)
			}
			$pomPath = ([IO.Path]::Combine($arrDirs) + "\$parentArtifactId\pom.xml") -replace ":", ":\"
			[void]$arrBuilds.Add($pomPath)
		} else {
			[void]$arrBuilds.Add($pom)
		}
	}
}
if ($arrBuilds.Count -gt 1) {
	$arrBuilds = $arrBuilds | Select-Object -Unique
}
#Write-Output "List of Parents"
#Write-Output $arrBuilds

#Check to see if something in the list is already a module of something else on the list
for ($i = 0; $i -le ($arrBuilds.Capacity - 1); $i++) {
	$pom = $arrBuilds[$i]
	if ($pom) {
		$xml = Get-XMLFile -xmlFile $pom
		foreach ($module in $xml.project.modules.module) {
			$module = $module -replace '\.', ''
			$module = $module -replace '\/', ''
			for ($x = 0; $x -le ($arrBuilds.Capacity - 1); $x++) {
				$build = $arrBuilds[$x]
				if ($build -match $module) {
					$arrBuilds.Remove($build)
				}
			}
		}
	}
}
if ($arrBuilds.Count -gt 1) {
	$arrBuilds = $arrBuilds | Select-Object -Unique
}
#Write-Output "List of Builds"
#Write-Output $arrBuilds

foreach ($pom in $arrBuilds) {
	#& mvn -B -f $pom clean
	#& mvn -B -f $pom install
	#& mvn -B -f $pom deploy
}

#Tell Fuse to install the new projects from Nexus
$servers = @("TXV12JBEQNC04")
foreach ($server in $servers) {
	#Write-Output "Starting $server"
	#Loop through poms and deploy dependencies, then the project
	foreach ($pom in $arrBuilds) {
		Write-Output "Reading $pom"
		$xml = Get-XMLFile -xmlFile $pom
		$projectGroupId = $xml.project.groupId
		$projectArtifactId = $xml.project.artifactId
		$projectVersion = $xml.project.version
		Write-Output "Checking on $($xml.project.dependencies.dependency.count) dependencies"
		foreach ($dependency in $xml.project.dependencies.dependency) {
			if ($dependency.groupId -match "com.equator") {
				$groupId = $dependency.groupId
				$artifactId = $dependency.artifactId
				$version = $dependency.version
				if ($groupId -match "com.equator.sm.ng") {
					$BundleLocation = "mvn:$groupId/$artifactId/$version"
					$build = $true
				} else {
					$BundleLocation = "wrap:mvn:$groupId/$artifactId/$version"
					$build = $true
					If ($artifactId -match "parent") {
						$build = $false
					}
				}
				if ($build) {
					[void]$arrBundles.Add($BundleLocation)
				}
			}
		}
		Write-Output "$projectArtifactId = $($xml.project.packaging)"
		if ($xml.project.packaging -ne "pom") {
			$BundleLocation = "mvn:$projectGroupId/$projectArtifactId/$projectVersion"
			[void]$arrBundles.Add($BundleLocation)
		}
	}
}
$arrBundles = $arrBundles | Select-Object -Unique
Write-Output $arrBundles

function Invoke-BundleReinstall {
	[CmdletBinding()]
	param ($BundleLocation,
		$server)
	Invoke-Command -ComputerName $server -ArgumentList $BundleLocation, $server -ScriptBlock {
		param ($BundleLocation,
			$server)
		$FuseHomeDirectory = 'D:\ServerBox\jboss-fuse-6.3.0.redhat-187'
		$username = 'admin'
		$password = 'admin'
		$FUSE_CLIENT_PORT = 8101
		$IPaddress = "10.158.45.61" #(Test-Connection $server -count 1 | Select-Object IPV4Address).IPV4Address.IPAddressToString
		Write-Output "Trying $BundleLocation"
		#Get Bundle ID
		$BundleID = Invoke-Expression "CMD /C $FuseHomeDirectory\bin\client.bat -a $FUSE_CLIENT_PORT -h $IPAddress -u $username -p $password ""osgi:id $BundleLocation""" 2>&1
		if ($BundleID) {
			#Uninstall Bundle
			Invoke-Expression "CMD /C $FuseHomeDirectory\bin\client.bat -a $FUSE_CLIENT_PORT -h $IPAddress -u $username -p $password ""osgi:uninstall --force $BundleID""" 2>&1
		}
		#Install Bundle
		Invoke-Expression "CMD /C $FuseHomeDirectory\bin\client.bat -a $FUSE_CLIENT_PORT -h $IPAddress -u $username -p $password ""osgi:install -s $BundleLocation""" 2>&1
	}
}

foreach ($bundle in $arrBundles) {
	Invoke-BundleReinstall -BundleLocation $bundle -server $server
}