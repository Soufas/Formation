Import-module activedirectory
$ModUsers = import-csv "c:\scripts\nis2ad\last_users.csv" -Delimiter :
$defpassword = (ConvertTo-SecureString "Des@1234" -AsPlainText -force)
foreach ($User in $ModUsers) {
$User.Name
$User.NA
$User.Uid
$User.Gid
$User.Nom
$User.Home
$User.Shell
Try {

$usernew = get-aduser $User.Name
#Set-ADUser -Identity $User.Name -replace @{unixHomeDirectory = ""}
#Set-ADUser -Identity $User.Name -replace @{loginShell = ""}
#Set-ADUser -Identity $User.Name -clear unixHomeDirectory
#Set-ADUser -Identity $User.Name -clear loginShell
} Catch {
#$User.Name | out-file "c:\scripts\users_not_exist_added.txt" -append
New-ADUser -SamAccountName $User.Name -Name $User.Nom -Enabled $true -ChangePasswordAtLogon $true -AccountPassword $defpassword -Path 'OU=Utilisateurs Linux,OU=Utilisateurs,OU=DES-SI,OU=RTE-DES,DC=gr0vsdma,DC=rte-france,DC=com'
Set-ADUser -Identity $User.Name -replace @{gidnumber = $User.Gid}
Set-ADUser -Identity $User.Name -replace @{uidnumber = $User.Uid}
Set-ADUser -Identity $User.Name -replace @{unixHomeDirectory = $User.Home}
Set-ADUser -Identity $User.Name -replace @{loginShell = $User.Shell}
}
}
