Import-Module eqDevOps
$dirs = Get-ChildItem -Filter "DevAgl - SMBuild*" -Directory
foreach ($dir in $dirs) {
	Edit-StringInFile -filePath "$dir\config.xml" -oldString '<rootPOM>D:\ServiceMart\ng' -newString '<rootPOM>D:\ServiceMart\DevAgl\ng'
}