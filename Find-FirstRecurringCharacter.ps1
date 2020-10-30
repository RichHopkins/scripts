function Find-FirstRecurringCharacter {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$testString
	)
	
	$chars = $teststring.ToCharArray()
	$charArray = @()
	for ($i = 0; $i -le $chars.Length; $i++) {
		$char = $chars[$i]
		if ($charArray -match $char) {
			return $char
			exit
		} else {
			$charArray += $char
		}
	}
}
