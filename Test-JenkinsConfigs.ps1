#Update all jobs that use Git to use the new release version
$jenkinsDirs = @(Get-ChildItem -Path "\\jenkins\d$\Jenkins\jobs" -Directory)

foreach ($jenkinsDir in $jenkinsDirs) {
	$jobPath = $jenkinsDir.FullName
	if (Test-Path "$jobPath\config.xml") {
		if (Get-Content "$jobPath\config.xml" | Select-String -Pattern '<scm class="hudson.plugins.git.GitSCM"') {
			$xml = [xml]((Get-Content "$jobPath\config.xml") -replace "xml\sversion='1\.1'", "xml version='1.0'")
			if ($xml.project) {
				$branchName = $xml.project.scm.branches.'hudson.plugins.git.BranchSpec'.name
				if (-not ($branchName -match 'release/13.03' -or $branchName -match "DevAgl")) {
					Write-Output "$jobPath\config.xml is using $branchName" #| Out-File -FilePath C:\test.log -Append
				}
			} elseif ($xml.'maven2-moduleset') {
				$branchName = $xml.'maven2-moduleset'.scm.branches.'hudson.plugins.git.BranchSpec'.name
				if (-not ($branchName -match 'release/13.03' -or $branchName -match "DevAgl")) {
					Write-Output "$jobPath\config.xml is using $branchName" #| Out-File -FilePath C:\test.log -Append
				}
			}
		}
	}
}

