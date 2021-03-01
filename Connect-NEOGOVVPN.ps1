<#
To setup the script do the following...

$username = $env:USERNAME
$domain = $env:USERDNSDOMAIN
$AESKey = New-Object Byte[] 32
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($AESKey)
$AESKey | Out-File "C:\$username@$domain.AES.key"
#You will need to manually type in your password to Read-Host
$PasswordSecureString = Read-Host -AsSecureString
$PasswordSecureString | ConvertFrom-SecureString -key $AESKey | Out-File -FilePath "C:\$username@$domain.securestring.txt"

#>

$vpnName = "NEOGOV VPN"
$username = $env:USERNAME
$domain = $env:USERDNSDOMAIN
$AESKey = Get-Content "C:\credFiles\$username@$domain.AES.key"
$EncryptedPasswordFile = "C:\credFiles\$username@$domain.securestring.txt"
#Use the Key to decrypt the password and load it into memory as a SecureString
[SecureString]$SecureStringPassword = Get-Content -Path $EncryptedPasswordFile | ConvertTo-SecureString -Key $AESKey
#Decrypt the SecureString to String
[String]$password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureStringPassword))
for ($i = 1; $i -le 3; $i++)
{
	$vpn = Get-VpnConnection -Name "NEOGOV VPN"
	If ($vpn.ConnectionStatus -eq "Disconnected")
	{
		rasdial $vpnName $username $password
	}
	else
	{
		exit 0
	}
	Start-Sleep -Seconds 15
}