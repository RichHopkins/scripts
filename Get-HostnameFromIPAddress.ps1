$ipaddress = Get-Content -Path C:\powershell-reports\ip.txt
$results = @()

ForEach ($i in $ipaddress) {
	$o = new-object psobject
	$o | Add-Member -MemberType NoteProperty -Name hostname -Value ([System.Net.Dns]::GetHostByAddress($i).HostName)
	$results += $o
}

$results | Select-Object -Property hostname | Export-Csv C:\powershell-reports\machinenames.csv