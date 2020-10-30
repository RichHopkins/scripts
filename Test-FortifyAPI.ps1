$baseUrl = 'https://api.ams.fortify.com/api/v3'
$token = 'SU9pMzxVRWZFZklhUXNaRWsyVD51YTBaLzZJZ3Mz0'
$bearer = ""
$header = @{
	Authorization = "Bearer $bearer"
}
$authHeader = @{
	scope      = "api-tenant"
	grant_type = "password"
	username   = "Altisource\richard.hopkins"
	password   = "Altisource1234!@#$"
}
$authHeader = @{
	scope = "api-tenant"
	grant_type = "client_credentials"
	client_id = "API_Token"
	client_secret = $token
}
$test = Invoke-WebRequest -Uri 'https://api.ams.fortify.com/oauth/token' -Headers $authHeader -Method POST