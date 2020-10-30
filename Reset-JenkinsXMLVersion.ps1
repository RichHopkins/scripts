Import-Module eqDevOps
$jobDirs = Get-ChildItem -Path "\\jenkins\d$\Jenkins\jobs" -Filter "Fortify * Test"
foreach ($dir in $jobDirs) {
	$jobConfig = $dir.FullName + "\config.xml"
	$content = (Get-Content $jobConfig)
	$fixed = $content.Replace('<?xml version=''1.1'' encoding=''UTF-8''?>', '<?xml version=''1.0'' encoding=''UTF-8''?>')
	Set-Content -Path $jobConfig -Value $fixed
}
