Import-Module ActiveDirectory
$userMails = @("Anju.MundackaplappillilJoseph@altisource.com", "Anupama.Birru@equator.com", "Belinda.Yan@equator.com", "Binod.Gurung@equator.com", "Blessy.Paul@equator.com", "Chi.Nguyen@equator.com", "Chris.Hazen@equator.com", "Dawn.Scott@equator.com", "Diganta.Choudhury@equator.com", "Jarad.Bernotavicz@equator.com ", "Kathryn.Pattengill@equator.com", "Katie.Moore@equator.com", "Krishna.Kothagundla@equator.com", "LaGale.Houston@equator.com", "Lavinia.Wolfgramm@equator.com", "Leeza.Kadavil@equator.com", "Linson.Abraham@equator.com", "Mai.Bui@equator.com", "Matthew.McHugh@equator.com", "Michael.DeJonghe@altisource.com", "Moira.Polius@equator.com", "Neethi.Shenoy@equator.com", "Nikhil.Prakash@equator.com", "Pradeep.Manoharan@equator.com", "Puneeth.Shivashankara@equator.com", "RaghuNandan.Chintalapudi@equator.com", "Ranjeeth.Vasikarla@equator.com", "Rinoy.Tharakan@equator.com", "Samuel.Shapiro@equator.com", "Sindhura.Deevakonda@equator.com", "Sinuhe.Sustaita@equator.com", "Sreelakhsmi.Viswanathan@equator.com", "Sreelal.Prasad@equator.com", "Suman.Vollala@equator.com", "Timothy.Lane@equator.com", "Tinu.Jacob@equator.com")
$users = Get-ADUser -Filter * -Properties MemberOf, mail
ForEach ($user in $users) {
	If ($user.mail -ne $null) {
		If ($userMails -match $user.mail) {
			If (-not ($user.MemberOf -match "Atlassian-Jira")) {
				Write-Output "Add user $($user.SamAccountName) to Jira"
				#Add-ADGroupMember -Identity "GS-Atlassian-Jira.Users.Corp" -Members $user.SamAccountName
			} Else {
				Write-Output "$($user.SamAccountName) is a Jira user"
			}
			If (-not ($user.MemberOf -match "Atlassian-Confluence")) {
				Write-Output "Add user $($user.SamAccountName) to Confluence"
				#Add-ADGroupMember -Identity "GS-Atlassian-Confluence.Users.Corp" -Members $user.SamAccountName
			} Else {
				Write-Output "$($user.SamAccountName) is a Confluence user"
			}
		}
	}
}