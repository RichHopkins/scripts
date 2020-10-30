<#
	.SYNOPSIS
		Queries the ProdTools Manifest table for files and records to delete.
	
	.DESCRIPTION
		Uses batchID and fileName parameters to search the Manifest table for files that need to be deleted.
		For any records found, use the file_path data column to attempt deleting the file and removing the SQL record when done.
	
	.PARAMETER batchID
		batchID to find the file in.
	
	.PARAMETER fileName
		Name of the file to purge.
	
	.PARAMETER SQLServer
		SQL Server that has the ProdTools database. Defaults to the Dev server TXV8SQEQNC01.
	
	.EXAMPLE
		Remove-ManifestFile -batchID "18" -fileName "1234.pdf" -SQLServer "TXV8SQEQNC01"

		Queries Dev ProdTools for files named 1234.pdf in batch 18, then deletes the files in in file_path and removes the record from the table.
#>
[CmdletBinding()]
param
(
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string]$batchID,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string]$fileName,
	[string]$SQLServer = "TXV8SQEQNC01"
)

[string]$SQLDatabase = "ProdTools"
[string]$SQLTable = "Manifest"

$SQLConnection = New-Object Data.SqlClient.SqlConnection
$SQLConnection.ConnectionString = "Server=$SQLServer;Database=$SQLDatabase;Trusted_Connection=Yes;Integrated Security=SSPI;"
Write-Verbose "Attempting connection: Server=$SQLServer;Database=$SQLDatabase"
try {
	$SQLConnection.Open()
} catch {
	Write-Error "Unable to connect: Server=$SQLServer;Database=$SQLDatabase"
	Write-Error $_.Exception.Message
	throw $_
}
[string]$SQLQuery = "SELECT * FROM MANIFEST(NOLOCK) WHERE BATCH_ID=$batchID AND FILE_NAME=`'$fileName`'"
$SQLCmd = New-Object System.Data.SqlClient.SqlCommand $SQLQuery, $SQLConnection
Write-Verbose "Executing Query: $SQLQuery"
Try {
	$adapter = New-Object System.Data.SqlClient.SqlDataAdapter $SQLCmd
	$dataset = New-Object System.Data.DataSet
	$adapter.Fill($dataset)
} catch {
	Write-Error $_.Exception.Message
	throw $_
}

ForEach ($filepath in $dataset.Tables.file_path) {
	If (Test-Path $filepath) {
		Write-Verbose "Deleting $filepath"
		Try {
			Remove-Item $filepath -Force | Out-Null
			$SQLQuery = "DELETE FROM $SQLTable WHERE BATCH_ID=$batchID AND FILE_PATH=`'$filepath`'"
			$SQLCmd.CommandText = $SQLQuery
			Write-Verbose "Executing SQL Command: $SQLQuery"
			Try {
				$SQLCmd.ExecuteNonQuery() | Out-Null
			} Catch {
				Write-Error "Error executing: $SQLQuery"
				Write-Error $_.Exception.Message
			}
			$SQLQuery = ""
		} Catch {
			Write-Error $_.Exception.Message
		}
	} Else {
		Write-Output "$filepath was not found."
		Write-Output "Run the following SQL command manually on $SQLServer\ProdTools - "
		Write-Output "DELETE FROM $SQLTable WHERE BATCH_ID=$batchID AND FILE_PATH=`'$filepath`'"
		Write-Output " "
	}
}

$SQLCmd.Dispose()
$SQLConnection.Close()
$SQLConnection.Dispose()