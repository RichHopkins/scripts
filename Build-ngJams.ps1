$now = Get-Date
Set-Location D:\ng\ng-JAMS
$file = Get-Item "D:\ng\ng-JAMS\package.json"
if ($file.LastWriteTime -ge $now.AddMinutes(-5)) {
	npm install
}
ng build -c=devtools
robocopy D:\ng\ng-JAMS \\devtools.eqdev\ServerBox\Sites\DevTools\common\modules\Scheduler\static\ng-JAMS /mir /mt