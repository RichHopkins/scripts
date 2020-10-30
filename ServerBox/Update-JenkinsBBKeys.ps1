param ([string]$jobPath = "\\txv12doeqnc01\d$\jenkins\jobs")

$oldString = 'https://eqalm.hq.reotrans.com/bitbucket/scm/eqbeqb'
$newString = 'https://eqalm.hq.reotrans.com/bitbucket/scm/eq'

$jenkinsDirs = @(Get-ChildItem -Path $jobPath -Directory)
foreach ($jenkinsDir in $jenkinsDirs) {
	$jobPath = $jenkinsDir.FullName
	if (Test-Path "$jobPath\config.xml") {
		if (Get-Content "$jobPath\config.xml" | Select-String -Pattern 'https:\/\/eqalm\.hq\.reotrans\.com\/bitbucket\/scm\/') {
			$config = [System.IO.File]::ReadAllText("$jobPath\config.xml").Replace($oldString, $newString)
			[System.IO.File]::WriteAllText("$jobPath\config.xml", $config)
		}
	}
}