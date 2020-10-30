Write-Output "Create shortcut on Desktop"
If (-not (Test-Path -Path "$Home\Desktop\InventoryDB.lnk")) {
	$WshShell = New-Object -ComObject WScript.Shell
	$Shortcut = $WshShell.CreateShortcut("C:\Users\$($env:USERNAME)\Desktop\InventoryDB.lnk")
	$Shortcut.TargetPath = "\\cacrpfs01\netshare\IT\Infrastructure\Desktop\Audit\Inventory.accde"
	$Shortcut.Save()
}
Write-Output "Create ODBC DSN Entry"
$DSNName = "InventoryDB"
$DBName = "Inventory"
$DBServer = "CACRPDFS01"
$HKLMPath1 = "HKLM:\SOFTWARE\ODBC\ODBC.INI\" + $DSNName
$HKLMPath2 = "HKLM:\SOFTWARE\ODBC\ODBC.INI\ODBC Data Sources"
If (-not (Test-Path -Path $HKLMPath1)) {
	MKDIR $HKLMPath1 -ErrorAction SilentlyContinue
	Set-ItemProperty -path $HKLMPath1 -name Driver -value "C:\Windows\system32\SQLSRV32.dll"
	Set-ItemProperty -path $HKLMPath1 -name Description -value $DSNName
	Set-ItemProperty -path $HKLMPath1 -name Server -value $DBServer
	Set-ItemProperty -path $HKLMPath1 -name LastUser -value ""
	Set-ItemProperty -path $HKLMPath1 -name Trusted_Connection -value "Yes"
	Set-ItemProperty -path $HKLMPath1 -name Database -value $DBName
}
If (-not (Test-Path -Path $HKLMPath2)) {
	MKDIR $HKLMPath2 -ErrorAction SilentlyContinue
	Set-ItemProperty -path $HKLMPath2 -name "$DSNName" -value "SQL Server"
}