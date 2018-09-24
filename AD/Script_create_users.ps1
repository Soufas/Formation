<#
.SYNOPSIS
Ce script à pour but d'automatiser un certain nombre de tâches liées à l'arrivée d'un utilisateur.
.DESCRIPTION
CreateUser permet d'automatiser les tâches suivantes :
Création du compte Windows
Ajout de l'utilisateur aux groupes par defaut
Ajout des permissions d'accès aux repertoires projet
Création du repertoire personnel (U:)
Création du repertoire d'archivage mail (M:)
Création d'un compte Linux (En cours de developpement)
.PARAMETER Name
Prend en paramétre le nom de l'utilisateur. Ce parametre est obligatoire.
.PARAMETER Firstname
Prend en paramétre le prénom de l'utilisateur. Ce parametre est obligatoire.
.PARAMETER Grp
Prend en paramétre le groupe par defaut de l'utilisateur. Ce parametre est obligatoire.
Voici la liste des valeurs possible DS, EM, EODCT, ES, GPM, INT.
.PARAMETER Type
Prend en paramétre le type de l'utilisateur. Ce parametre est oblicatoire.
Voici la liste des valeurs possible AGENTS, EXTERIEURS.
.PARAMETER Office
Prend en paramétre le bureau de l'utilisateur.
Le format de cet argument doit comprendre l'etage et le numero de bureau sur le modele EE/BBB. (Ex: 03/099)
.PARAMETER AccountExpirationDate
Prend en paramétre la date d'expiration du compte de l'utilisateur.
Pour rappel un agent ou un thesard ne dispose pas de date d'expiration.
Le format de la date doit respecter le modele JJ/MM/AAAA.
.PARAMETER AddGrps
Prend en paramétre les groupes à ajouter à l'utilisateur.
Il est necessaire de saisir le nom exact du groupe et de les separer par des virgules.
.EXAMPLE
Exemple 1 :
CreateUser
Lance le script en mode interactif.
.EXAMPLE
Exemple 2 :
CreateUser -Name Barbe -Firstname jerome -Grp DS -Type AGENTS
Lance la creation de l'utilisateur à l'aide des arguments saisie. (En cours de de developpement)
.NOTES
Author : Jerome BARBE
Version : 0.3
#>
#[CmdletBinding(SupportsShouldProcess=$true)]
#Param()
Param(
[Parameter(Mandatory=$False,Position=1)]
   [string]$Name,
   
 [Parameter(Mandatory=$False)]
   [string]$Firstname,
   
 [Parameter(Mandatory=$False)]
   [string]$Grp,
   
 [Parameter(Mandatory=$False)]
   [string]$Type, 
  
 [Parameter(Mandatory=$False)]
   [string]$Office,
   
 [Parameter(Mandatory=$False)]
   [string]$AccountExpirationDate,
   
 [Parameter(Mandatory=$False)]
   [array]$AddGrps,

   [switch]$DoSomething
)
#On encode la sortie powershell en UTF8
#chcp 65001
#$OutputEncoding = [Console]::OutputEncoding
#[Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8
$global:Gid =$null
function CreateLdapVaLues ([string]$Name, [string]$Firstname)
{
    $LDAP_Name = $Name.ToUpper()
    Write-Verbose "Modification du format du nom : $LDAP_Name"
	$OFS = ''
	$LDAP_FirstName = ([string]$FirstName[0]).ToUpper() + ([string]$FirstName.Substring(1)).ToLower()
    Write-Verbose "Modification du format du prenom : $LDAP_FirstName"
    $LDAP_CN = $LDAP_Name + " " + $LDAP_FirstName
    Write-Verbose "Creation du common name : $LDAP_CN"
    #Modification du nom dans le cas ou celui-ci est inferieur à 4 lettres
    If ($Name.Length -le 4)
    {
		for ($i = $Name.Length; $i -le 5; $i++)
		{
			$Name = $Name + "x"
		}
       Write-Verbose "Ajout de x au nom de l'utilisateur"
    }
    #Modification du prenom dans le cas ou celui-ci est inferieur à 4 lettres
    If ($FirstName.Length -le 4)
    {
		for ($i = $FirstName.Length; $i -le 5; $i++)
		{
			$FirstName = $FirstName + "x"
		}
       Write-Verbose "Ajout de x au prenom de l'utilisateur"
    }
    #Verification de la présence d'un - dans le prénom
    If ($FirstName.Contains('-')) 
    {
       Write-Verbose "Detection de la presence d'un - dans le prénom"
       $Firstname = ($FirstName.Substring(0,1)+$FirstName.Substring((($Firstname).IndexOf("-")+1),(($Firstname.length - $Firstname.IndexOf("-"))-1)))
    }
    $Login = ($FirstName.Substring(0,4)+$Name.Substring(0,4)).ToLower()
    Write-Verbose "Creation du login : $Login"
    $LoginRequest = "False"
    while ($LoginRequest -eq "False") 
    {
       $erroractionpreference = "SilentlyContinue"
       $CheckLogin = Get-ADUser $Login
       If (($CheckLogin) -and ($ExecutionMod -eq "Cmd"))
       {
            Exit 3
       }
       ElseIf ($CheckLogin)
       {
           Write-warning "Erreur --> Le login $Login est deja utilisé"
           $Login = Read-Host "Veuillez saisir un nouveau login ?"
           Clear-Variable CheckLogin
       }
       Else
       {
           Write-Verbose "Le login $Login est disponible"
           $LoginRequest = "True"
           $LDAP_Login = $Login
           $Maj_LDAP_Login = $LDAP_Login.ToUpper()
       }
    }
    #Initialisation des initials
    $LDAP_Initials = ($FirstName.Substring(0,1).ToUpper()+$Name.Substring(0,1)).ToUpper()
    Write-Verbose "Creation des initials : $LDAP_initials"
    #Intitialisation de l'adresse mail
    $LDAP_Mail =  $LDAP_FirstName.ToLower()+"."+$LDAP_Name.ToLower()+"@rte-france.com"
    Write-Verbose "Creation de l'adresse mail : $LDAP_Mail"
    #Initialisation du mot de passe temporaire
    [Reflection.Assembly]::LoadWithPartialName("System.Web")>$null #Chargement de la blibliotheque Assembly et utilisation de la méthode LoadWithPartialNam
    $LDAP_Password = [System.Web.Security.Membership]::GeneratePassword(8,0)
    Write-Verbose "Initialisation du mot de passe temporaire : $LDAP_Password"
	return $LDAP_Name, $LDAP_FirstName, $LDAP_Initials, $LDAP_CN, $LDAP_Mail, $LDAP_Login, $LDAP_Password 
}

function CreateAccount ([string]$LDAP_Name, [string]$LDAP_Firstname, [string]$LDAP_Initials, [string]$LDAP_CN, [string]$LDAP_Mail, [string]$LDAP_Office, [string]$LDAP_Login, [string]$LDAP_Password, [string]$LDAP_Grp, [string]$LDAP_AccountExpirationDate)
{
	$lieuUtilisateur = Read-Host "Où le user sera-t-il situé? `n[1]- Versailles `n[2]- NextDoor`n"
	switch ($lieuUtilisateur)
	{
		1
		{
			$descriptionUtilisateur = Read-Host "Le user est-il? `n[1]- Un prestataire `n[2]- Un agent `n[3]- Un stagiaire`n"
			switch ($descriptionUtilisateur)
			{
				1
				{
					$descriptionUtilisateur = "Prestataire"
					Set-Variable Gid -Value 5001 -Scope Global
				}
				2
				{
					$descriptionUtilisateur = "Agent"
					Set-Variable Gid -Value 5000 -Scope Global
				}
				3
				{
					$descriptionUtilisateur = "Stagiaire"
					Set-Variable Gid -Value 5002 -Scope Global
				}
			}
			Write-Verbose "Creation du compte Active Directory $LDAP_Login"
			$AccountPassword = (ConvertTo-SecureString $LDAP_Password -AsPlainText -force)
			If ($LDAP_AccountExpirationDate -eq "")
			{
				if ($GrpModChoice -eq "26" -or $GrpModChoice -eq "27") #Cas Particulier Stagiaires et RH
				{
					$path = "OU=Utilisateurs,OU=$LDAP_Grp,OU=RTE-DES,DC=GR0VSDMA,DC=RTE-FRANCE,DC=COM"
				}
				elseif ($GrpModChoice -eq "2") #Cas Particulier SI
				{
					$path = "OU=Utilisateurs Classiques,OU=Utilisateurs,OU=DES-SI,OU=RTE-DES,DC=GR0VSDMA,DC=RTE-FRANCE,DC=COM"
				}
				elseif ($GrpModChoice -eq "8") #Cas Particulier MCO Convergence
				{
					$path = "OU=Utilisateurs,OU=$LDAP_Grp,OU=Convergence,OU=Projets DES,OU=RTE-DES,DC=GR0VSDMA,DC=RTE-FRANCE,DC=COM"
				}
				else
				{
					$path = "OU=Utilisateurs,OU=$LDAP_Grp,OU=Projets DES,OU=RTE-DES,DC=GR0VSDMA,DC=RTE-FRANCE,DC=COM"
				}
				New-ADUser -SamAccountName $LDAP_Login -UserPrincipalName $LDAP_Login"@gr0vsdma.rte-france.com" -Name $LDAP_CN -GivenName $LDAP_Firstname -Surname $LDAP_Name -DisplayName $LDAP_CN -Initials $LDAP_Initials -Description $descriptionUtilisateur -EmailAddress $LDAP_Mail -Office $LDAP_Office -City "VERSAILLES" -PostalCode "78005 Cedex" -POBox "BP 561" -State "Yvelines - IDF" -StreetAddress "9, Route de la Porte de Buc" -Country "FR" -ScriptPath "Dma.bat" -Department "Groupe $LDAP_Grp" -Company "RTE DES" -Path $path -AccountPassword $AccountPassword -Enabled $true -ChangePasswordAtLogon $true
			}
			Else
			{
				if ($GrpModChoice -eq "26" -or $GrpModChoice -eq "27") #Cas Particulier Stagiaires et RH
				{
					$path = "OU=Utilisateurs,OU=$LDAP_Grp,OU=RTE-DES,DC=GR0VSDMA,DC=RTE-FRANCE,DC=COM"
				}
				elseif ($GrpModChoice -eq "2") #Cas Particulier SI
				{
					$path = "OU=Utilisateurs Classiques,OU=Utilisateurs,OU=DES-SI,OU=RTE-DES,DC=GR0VSDMA,DC=RTE-FRANCE,DC=COM"
				}
				elseif ($GrpModChoice -eq "8") #Cas Particulier MCO Convergence
				{
					$path = "OU=Utilisateurs,OU=$LDAP_Grp,OU=Convergence,OU=Projets DES,OU=RTE-DES,DC=GR0VSDMA,DC=RTE-FRANCE,DC=COM"
				}
				else
				{
					$path = "OU=Utilisateurs,OU=$LDAP_Grp,OU=Projets DES,OU=RTE-DES,DC=GR0VSDMA,DC=RTE-FRANCE,DC=COM"
				}
				New-ADUser -SamAccountName $LDAP_Login -UserPrincipalName $LDAP_Login"@gr0vsdma.rte-france.com" -Name $LDAP_CN -GivenName $LDAP_Firstname -Surname $LDAP_Name -DisplayName $LDAP_CN -Initials $LDAP_Initials -Description $descriptionUtilisateur -EmailAddress $LDAP_Mail -Office $LDAP_Office -City "VERSAILLES" -PostalCode "78005 Cedex" -POBox "BP 561" -State "Yvelines - IDF" -StreetAddress "9, Route de la Porte de Buc" -Country "FR" -ScriptPath "Dma.bat" -Department "Groupe $LDAP_Grp" -Company "RTE DES" -Path $path -AccountExpirationDate $LDAP_AccountExpirationDate -AccountPassword $AccountPassword -Enabled $true -ChangePasswordAtLogon $true
			}
		}
		2
		{
			$descriptionUtilisateur = Read-Host "Le user est-il? `n[1]- Un prestataire `n[2]- Un agent `n[3]- Un stagiaire`n"
			switch ($descriptionUtilisateur)
			{
				1
				{
					$descriptionUtilisateur = "Prestataire"
					Set-Variable Gid -Value 5001 -Scope Global
				}
				2
				{
					$descriptionUtilisateur = "Agent"
					Set-Variable Gid -Value 5000 -Scope Global
				}
				3
				{
					$descriptionUtilisateur = "Stagiaire"
					Set-Variable Gid -Value 5002 -Scope Global
				}
			}
			Write-Verbose "Creation du compte Active Directory $LDAP_Login"
			$AccountPassword = (ConvertTo-SecureString $LDAP_Password -AsPlainText -force)
			If ($LDAP_AccountExpirationDate -eq "")
			{
				if ($GrpModChoice -eq "26" -or $GrpModChoice -eq "27") #Cas Particulier Stagiaires et RH
				{
					$path = "OU=Utilisateurs,OU=$LDAP_Grp,OU=RTE-DES,DC=GR0VSDMA,DC=RTE-FRANCE,DC=COM"
				}
				elseif ($GrpModChoice -eq "2") #Cas Particulier SI
				{
					$path = "OU=Utilisateurs Classiques,OU=Utilisateurs,OU=DES-SI,OU=RTE-DES,DC=GR0VSDMA,DC=RTE-FRANCE,DC=COM"
				}
				elseif ($GrpModChoice -eq "8") #Cas Particulier MCO Convergence
				{
					$path = "OU=Utilisateurs,OU=$LDAP_Grp,OU=Convergence,OU=Projets DES,OU=RTE-DES,DC=GR0VSDMA,DC=RTE-FRANCE,DC=COM"
				}
				else
				{
					$path = "OU=Utilisateurs,OU=$LDAP_Grp,OU=Projets DES,OU=RTE-DES,DC=GR0VSDMA,DC=RTE-FRANCE,DC=COM"
				}
				New-ADUser -SamAccountName $LDAP_Login -UserPrincipalName $LDAP_Login"@gr0vsdma.rte-france.com" -Name $LDAP_CN -GivenName $LDAP_Firstname -Surname $LDAP_Name -DisplayName $LDAP_CN -Initials $LDAP_Initials -Description $descriptionUtilisateur -EmailAddress $LDAP_Mail -Office $LDAP_Office -City "COURBEVOIE" -PostalCode "92026 Cedex" -State "La Défense - IDF" -StreetAddress "110 Espl. du Général de Gaulle" -Country "FR" -ScriptPath "Dma.bat" -Department "Groupe $LDAP_Grp" -Company "RTE DES" -Path $path -AccountPassword $AccountPassword -Enabled $true -ChangePasswordAtLogon $true
			}
			Else
			{
				if ($GrpModChoice -eq "26" -or $GrpModChoice -eq "27") #Cas Particulier Stagiaires et RH
				{
					$path = "OU=Utilisateurs,OU=$LDAP_Grp,OU=RTE-DES,DC=GR0VSDMA,DC=RTE-FRANCE,DC=COM"
				}
				elseif ($GrpModChoice -eq "2") #Cas Particulier SI
				{
					$path = "OU=Utilisateurs Classiques,OU=Utilisateurs,OU=DES-SI,OU=RTE-DES,DC=GR0VSDMA,DC=RTE-FRANCE,DC=COM"
				}
				elseif ($GrpModChoice -eq "8") #Cas Particulier MCO Convergence
				{
					$path = "OU=Utilisateurs,OU=$LDAP_Grp,OU=Convergence,OU=Projets DES,OU=RTE-DES,DC=GR0VSDMA,DC=RTE-FRANCE,DC=COM"
				}
				else
				{
					$path = "OU=Utilisateurs,OU=$LDAP_Grp,OU=Projets DES,OU=RTE-DES,DC=GR0VSDMA,DC=RTE-FRANCE,DC=COM"
				}
				New-ADUser -SamAccountName $LDAP_Login -UserPrincipalName $LDAP_Login"@gr0vsdma.rte-france.com" -Name $LDAP_CN -GivenName $LDAP_Firstname -Surname $LDAP_Name -DisplayName $LDAP_CN -Initials $LDAP_Initials -Description $descriptionUtilisateur -EmailAddress $LDAP_Mail -Office $LDAP_Office -City "COURBEVOIE" -PostalCode "92026 Cedex" -State "La Défense - IDF" -StreetAddress "110 Espl. du Général de Gaulle" -Country "FR" -ScriptPath "Dma.bat" -Department "Groupe $LDAP_Grp" -Company "RTE DES" -Path $path -AccountExpirationDate $LDAP_AccountExpirationDate -AccountPassword $AccountPassword -Enabled $true -ChangePasswordAtLogon $true
			}
		}
	}
}

function AddGroup ([string]$LDAP_Grp, [string]$LDAP_Login, [string]$UserType, [array]$LDAP_TabRight)
{
	Write-Verbose "Ajout de l'utilisateur aux groupes d'accès"
	Add-ADGroupMember -Identity GG-DES-$LDAP_Grp -Member $LDAP_Login
	Add-ADGroupMember -Identity GG-DES_$UserType -Member $LDAP_Login
	If (!$(!$LDAP_TabRight.length))
	{
		Foreach ($Right in $LDAP_TabRight)
		{
			Add-ADGroupMember -Identity $Right -Member $LDAP_Login
		}
	}
}

function GenerateUID()
{
  $LastUID = Get-Content -Path C:\scripts\UID_LAST_NUMBER.txt
  $intLastUID= [int]$LastUID +1
  $intLastUID > C:\scripts\UID_LAST_NUMBER.txt
  return $intLastUID
}

function CreateFolders ([string]$LDAP_Login)
{
	$Maj_LDAP_Login = $LDAP_Login.ToUpper()
	$cheminReseau = "\\gr0vsdma.rte-france.com\datas\winusers\$Maj_LDAP_Login"
	#Creation du repertoire de personnel de l'utilisateur sur le DFS et modification des droits par defaut
	Write-Verbose "Création du répertoire Winuser"
	New-Item -Path $cheminReseau -ItemType Directory
	#Ajout du Quota au dossier Winuser
	$chemin = "E:\$Maj_LDAP_Login"
	$scriptBlock1GB = {
		param ([string[]]$chemin)
		New-FsrmQuota -Path $chemin -Template "1GB" | Out-Null
	}
	Invoke-Command -Computer "WINUSERS" -ScriptBlock $scriptBlock1GB -ArgumentList $( ,$chemin) #Permet de créer le quota de l'utilisateur sur le DFS
	Write-Verbose "Modification des droits NTFS du repertoire $Maj_LDAP_Login"
	$acl = Get-Acl "\\gr0vsdma.rte-france.com\datas\winusers\$Maj_LDAP_Login"
	$acl.SetAccessRuleProtection($True, $False) 
	#Desactive l'heritage
	$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("GR0VSDMA\Admins du domaine","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
	$acl.AddAccessRule($rule)
	$login = "GR0VSDMA\$Maj_LDAP_Login"
	$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($login,"Modify", "ContainerInherit, ObjectInherit", "None", "Allow") 
	$acl.AddAccessRule($rule)
	Set-Acl "\\gr0vsdma.rte-france.com\datas\winusers\$Maj_LDAP_Login" $acl

	#Création du repertoire d'archivage mail et modification des droits par defaut
	Write-Verbose "Creation du repertoire de l'utilisateur $LDAP_Login (M:)"
	New-Item -ItemType directory -Name $LDAP_Login -Path "\\gr0vsdma.rte-france.com\data\Archivage_Mail\"
	Write-Verbose "Modification des droits NTFS du repertoire $LDAP_Login"
	$acl = Get-Acl "\\gr0vsdma.rte-france.com\data\Archivage_Mail\$LDAP_Login"
	$acl.SetAccessRuleProtection($True, $False) 
	#Desactive l'heritage
	$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("GR0VSDMA\Admins du domaine","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
	$acl.AddAccessRule($rule)
	$login = "GR0VSDMA\$Maj_LDAP_Login"
	$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($login, "Modify", "ContainerInherit, ObjectInherit", "None", "Allow")
	$acl.AddAccessRule($rule)
	Set-Acl "\\gr0vsdma.rte-france.com\data\Archivage_Mail\$LDAP_Login" $acl
}

function CreateMail ([string]$LDAP_CN, [string]$LDAP_Login, [string]$LDAP_Password, [string]$LDAP_AccountExpirationDate, [string]$LDAP_Office)
{
	Write-Verbose "Création d'un mail recapitulatif"
	$dateJ=get-date -uformat "%Y%m%d"
	$expediteur = "GROVSW1F@gr0vsdma.rte-france.com"
	$destinataire = "rte-fcent-moa-si-dma@rte-france.com"
	$serveur = "163.104.9.110"
	#$objet = "Création d'un accès Utilisateur Windows pour $LDAP_CN le " + [System.DateTime]::Now
	$objet = "Création d'un accès Utilisateur Windows pour $LDAP_CN"
	If ($LDAP_AccountExpirationDate -eq "")
	{
		$LDAP_AccountExpirationDate = "--"
	}
	If ($LDAP_Office -eq "")
	{
		$LDAP_Office = "--"
	} 
	$texte = "Bonjour,<br><br> <u><b>Voici les informations concernant la création de l'utilisateur :</b></u><br><br> Nom complet :<bq> $LDAP_CN <br> Bureau :<bq> $LDAP_Office <br> Login :<bq> $LDAP_Login <br> Mdp :<bq> $LDAP_Password <br> Date d'expiration :<bq> $LDAP_AccountExpirationDate <br><br>Vous serez invité à changer votre mot de passe lors de la première connexion.<br>Ceci est un compte personnel et vous êtes responsable de la confidentialité de votre mot de passe. Les mots de passe doivent avoir au moins 8 caractères.<br><br> Cordialement"
	$message = new-object System.Net.Mail.MailMessage $expediteur, $destinataire, $objet, $texte 
	$message.IsBodyHTML = $true
	$SMTPclient = new-object System.Net.Mail.SmtpClient $serveur
	$SMTPclient.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
	$SMTPclient.Send($message) 
}
#Programme Principal
Write-Verbose "Chargement du module Actice Directory"
Import-Module ActiveDirectory
If ((($psboundparameters.count) -eq 0) -or ((($psboundparameters.count) -eq 1) -and ($PSBoundParameters['Verbose'] -eq $true)))
{
    Write-Verbose "Lancement du script en mode interractif"
    $ExecutionMod= "Interractif"
    $NameRequest = ""
        while ($NameRequest -eq "")
        {
            $NameRequest=Read-Host "Quel est le nom du nouvel utilisateur ?"
            If ($NameRequest -eq "")
            {
                Write-warning "Erreur --> Le champ nom est obligatoire."
            }
        }
        $FirstNameRequest = ""
            while ($FirstNameRequest -eq "")
            {
                $FirstNameRequest = Read-Host "Quel est le prenom du nouvel utilisateur ?"
                If ($FirstNameRequest -eq "")
                {
                    Write-warning "Erreur --> Le champ prenom est obligatoire."
                }
            }
            #Check de la presence du login dans l'AD
            $PreLogin = ($FirstNameRequest.Substring(0,4)+$NameRequest.Substring(0,4)).ToLower()
            #$CheckPreLogin = get-ADUser $PreLogin 
			Try { $CheckPreLogin = get-ADUser $PreLogin -ErrorVariable Err -ErrorAction SilentlyContinue } 
            Catch { write-host "" }	 
			
            If ($CheckPreLogin)
            {
				Write-host "Le login existe dans Active directory" -foregroundcolor Yellow
				Write-host "Le script se ferme !" -foregroundcolor Yellow
				BREAK
                 
            }
			else
			{
				Write-host "le login est disponible" -foregroundcolor Green

			}
            #Initialisation du groupe par defaut
            $GrpRequest = "False"
            while ($GrpRequest -eq "False")
                {
                    $GrpModChoice = Read-Host "Quel est le groupe par defaut de l'utilisateur ?`n[1]- Antares `n[2]- SI `n[3]- Apogee `n[4]- Assess `n[5]- Calcul de Capa `n[6]- CDP Prod `n[7]- Convergence `n[8]- MCO Convergence `n[9]- Coreso `n[10]- Dynamo `n[11]- e-Highway `n[12]- ENR `n[13]- Eurostag `n[14]- Garpur `n[15]- HVDC `n[16]- Inprove `n[17]- iTesla `n[18]- Migrate  `n[20]- Optimal Powerflow `n[21]- Optimate `n[22]- PopCorn `n[23]- Ringo `n[24]- RSCT `n[25]- Smartlab `n[26]- RH `n[27]- Stagiaires `n"
                    switch ($GrpModChoice) 
                    {
						1
						{
							$LDAP_Grp = "Antares"
							$GrpRequest = "True"
						}
						2
						{
							$LDAP_Grp = "SI"
							$GrpRequest = "True"
						}
						3
						{
							$LDAP_Grp = "Apogee"
							$GrpRequest = "True"
						}
						4
						{
							$LDAP_Grp = "Assess"
							$GrpRequest = "True"
						}
						5
						{
							$LDAP_Grp = "Calcul de Capa"
							$GrpRequest = "True"
						}
						6
						{
							$LDAP_Grp = "CDP Prod"
							$GrpRequest = "True"
						}
						7
						{
							$LDAP_Grp = "Convergence"
							$GrpRequest = "True"
						}
						9
						{
							$LDAP_Grp = "MCO Convergence"
							$GrpRequest = "True"
						}
						10
						{
							$LDAP_Grp = "Dynamo"
							$GrpRequest = "True"
						}
						11
						{
							$LDAP_Grp = "e-Highway"
							$GrpRequest = "True"
						}
			
						12
						{
							$LDAP_Grp = "ENR"
							$GrpRequest = "True"
						}
						13
						{
							$LDAP_Grp = "Eurostag"
							$GrpRequest = "True"
						}
						14
						{
							$LDAP_Grp = "Garpur"
							$GrpRequest = "True"
						}
						15
						{
							$LDAP_Grp = "HVDC"
							$GrpRequest = "True"
						}
						16
						{
							$LDAP_Grp = "Inprove"
							$GrpRequest = "True"
						}
						17
						{
							$LDAP_Grp = "iTesla"
							$GrpRequest = "True"
						}
						18
						{
							$LDAP_Grp = "Migrate"
							$GrpRequest = "True"
						}
						19
						{
							$LDAP_Grp = "ODCT (pôle)"
							$GrpRequest = "True"
						}
						20
						{
							$LDAP_Grp = "Optimal Powerflow"
							$GrpRequest = "True"
						}
						21
						{
							$LDAP_Grp = "Optimate"
							$GrpRequest = "True"
						}
						22
						{
							$LDAP_Grp = "PopCorn"
							$GrpRequest = "True"
						}
						23
						{
							$LDAP_Grp = "Ringo"
							$GrpRequest = "True"
						}
						24
						{
							$LDAP_Grp = "RSCT"
							$GrpRequest = "True"
						}
						25
						{
							$LDAP_Grp = "Smartlab"
							$GrpRequest = "True"
						}
						26
						{
							$LDAP_Grp = "RH"
							$GrpRequest = "True"
						}
						27
						{
							$LDAP_Grp = "Stagiaires"
							$GrpRequest = "True"
						}
						default
						{
                        	Write-Warning "Erreur --> Le choix effectué n'existe pas."
                        }
                    } 
                }
                #Initialisation du type de l'utilisateur
                $LDAP_AccountExpirationDate = ""
                $UserTypeModChoice = Read-Host "Quel est le statut de l'utilisateur ?`n[1]- Agent ou Thesard ou Intérimaire`n[2]- Stagiaire ou Prestataire `n"
                switch ($UserTypeModChoice) 
                {
					1
					{
						$UserType = "AGENTS"
					}
					2
					{
						$UserType = "EXTERIEURS"
					}
					default
					{
						Write-Warning "Erreur --> Le choix effectué n'existe pas."
						exit 1
					}
				} 
				#Initialisation de la date d'expiration du compte dans le cas d'un agent ou d'un thesard
				If (!($UserType -eq "AGENTS"))
				{
					#Verification du format de la date
					$LDAP_AccountExpirationDate = Read-Host "Quel est la date de départ de l'utilisateur ? (JJ/MM/AAAA)"
					$DateRequest = "False"
					while ($DateRequest -eq "False")
					{
						If((($LDAP_AccountExpirationDate).Length -eq 10) -and (($LDAP_AccountExpirationDate).Substring(2,1) -eq "/") -and (($LDAP_AccountExpirationDate).Substring(5,1) -eq "/") -and (($LDAP_AccountExpirationDate).Substring(0,2) -le 31) -and (($LDAP_AccountExpirationDate).Substring(3,2) -le 12) -and (($LDAP_AccountExpirationDate).Substring(6,2) -eq 20))
						{
							$Timespan = New-TimeSpan -Start (get-date) -End (Get-Date -Day ($LDAP_AccountExpirationDate).Substring(0,2) -Month ($LDAP_AccountExpirationDate).Substring(3,2) -Year ($LDAP_AccountExpirationDate).Substring(6,4))
							If ($Timespan -lt 0)
							{
								Write-warning "Erreur --> La date doit être posterieur à aujourd'hui"
								$LDAP_AccountExpirationDate = Read-Host "Quel est la date de départ de l'utilisateur ? (JJ/MM/AAAA)"
							}
							Else 
							{
								$DateRequest = "True"
							}
						}
						Else
						{
							Write-warning "Erreur --> La date n'est pas au bon format"
							$LDAP_AccountExpirationDate = Read-Host "Quel est la date de départ de l'utilisateur ? (JJ/MM/AAAA)"
						}
					}
				}
	#Initialisation du bureau de l'utilisateur
	$LDAP_Office = Read-Host "Quel est le numero du bureau de l'utilisateur ? Ex: (02/099)"
	#Initialisation des groupes supplémentataire
	$TabRight = @()
	$GrpAdditionalRequest = "False"
	while ($GrpAdditionalRequest -eq "False") 
	{  
		$GrpAdditionalChoice = Read-Host "Voulez vous ajouter des accès à des repertoires projet ?`n[1]- Oui `n[2]- Non `n"
		switch ($GrpAdditionalChoice) 
		{
			1
			{
				$ProjectResearch = Read-Host "Quel dossier projet recherchez vous ? Ex:(OPTI)"
				$GrpSuggest = Get-ChildItem -Path "\\gr0vsdma.rte-france.com\datas\winprojets\" | Where-Object { $_.name -like "$ProjectResearch*" }
				$i = 1
				If (!$GrpSuggest.count)
				{
					Write-Warning "Erreur --> Pas de suggestion(s)."
				}
				Else
				{
					Foreach ($valeur in $GrpSuggest)
					{
						write-host "$i - $valeur"
						$i++
					}
					
					$ProjectNumberChoice = Read-Host "Veuillez saisir le chiffre correspondant au dossier recherché ?"
					$ProjectCheck = $GrpSuggest[$ProjectNumberChoice - 1]
					$ProjectCheckModL = "GG-" + "$ProjectCheck".Replace(' ', '_') + "_L"
					$ProjectCheckModM = "GG-" + "$ProjectCheck".Replace(' ', '_') + "_M"
					$RightProjectRequest = Read-Host "Voulez vous accorder des droits de lecture (L) ou de lecture/ecriture (M) ? `n[1]- L `n[2]- M `n"
				}
				switch ($RightProjectRequest)
				{
					1
					{
						If (Get-ADGroup -Filter {SamAccountName -eq $ProjectCheckModL})
						{
							$TabRight += $ProjectCheckModL.ToUpper()
						}
						Else 
						{
							Write-Warning "Erreur --> Le groupe $ProjectCheckModL n'existe pas dans l'AD"
						}
					}
					2
					{
						If (Get-ADGroup -Filter {SamAccountName -eq $ProjectCheckModM})
						{
							$TabRight += $ProjectCheckModM.ToUpper()
						}
						Else 
						{
							Write-Warning "Erreur --> Le groupe $ProjectCheckModM n'existe pas dans l'AD"
						}
					}
					default
					{
						Write-Warning "Erreur --> Le choix effectué n'existe pas."
					}
				}
			}
			2
			{
				$GrpAdditionalRequest = "True"
			}
			default
			{
				
				Write-Warning "Erreur --> Le choix effectué n'existe pas."
			}
		}
	}
	$LDAP_Name,$LDAP_FirstName,$LDAP_Initials,$LDAP_CN,$LDAP_Mail,$LDAP_Login,$LDAP_Password = CreateLdapValues $NameRequest $FirstNameRequest
	write-host "-----------------------------------------------------"
	write-host "Voici un recapitulatif des données de l'utilisateur :" -foregroundcolor Magenta
	write-host "-----------------------------------------------------"
	write-host "Nom : $LDAP_Name"           
	write-host "Prenom : $LDAP_FirstName"
	write-host "Initials : $LDAP_Initials"
	write-host "Common Name : $LDAP_CN"
	write-host "Adresse Mail : $LDAP_Mail"
	If ($LDAP_Office -eq "")
	{
		write-host "Bureau : --"
	}
	Else
	{
		write-host "Bureau : $LDAP_Office"
	}
	write-host "Login : $LDAP_Login"
	If ($LDAP_AccountExpirationDate -eq "")
	{
		write-host "Date d'expiration du compte : --"
	}
	Else
	{
		write-host "Date d'expiration du compte : $LDAP_AccountExpirationDate"
	}
	write-host "Groupes par default :           GG-DES-$LDAP_Grp"
	write-host "                                      GG-DES_$UserType"
	If ($(!$TabRight.length))
	{
		write-host "Groupes additionnel : --"
	}
	Else
	{ 
		write-host "Groupes additionnel : "
		foreach ($Right in $TabRight)
		{
			write-host "                                      $Right"
		}
	}
	write-host "-----------------------------------------------------"
	write-host ""
	$CreateRequest = "False"
	while ($CreateRequest -eq "False")
	{
		$CreateModChoice = Read-Host "Voulez vous lancer la procedure de création ?`n[1]- Oui `n[2]- Non `n"
		switch ($CreateModChoice) 
		{
			1
			{
				$CreateRequest = "True"
				Write-Verbose "Lancement de la creation ..."
				CreateAccount $LDAP_Name $LDAP_FirstName $LDAP_Initials $LDAP_CN $LDAP_Mail $LDAP_Office $LDAP_Login $LDAP_Password $LDAP_Grp $LDAP_AccountExpirationDate
				Addgroup $LDAP_Grp $LDAP_Login $UserType $TabRight
				CreateFolders $LDAP_Login
				CreateMail $LDAP_CN $LDAP_Login $LDAP_Password $LDAP_AccountExpirationDate $LDAP_Office
				$GeneratedUID = GenerateUID
                Set-ADUser -Identity $LDAP_Login -replace @{uidnumber = $GeneratedUID}
		        Set-ADUser -Identity $LDAP_Login -replace @{gidnumber = $Gid}
				$command = "/root/scripts/createDirectory_afterNIS.sh $LDAP_Login"
		        plink.exe -ssh -l root -pw install filer2 $command
				Write-Verbose "Fin d'execution du script"
			}
			2
			{
				Write-Verbose "Fin d'execution du script"
				exit 1
			}
			default
			{
				Write-Warning "Erreur --> Le choix effectué n'existe pas."
			}
		} 
	}
}
Else 
{
	$LDAP_Office =""
	$ExecutionMod= "Cmd"
	write-host "Analyse des arguments" 
	If (($Name -eq "") -or ($Firstname -eq "") -or ($Grp -eq "") -or ($Type -eq ""))
	{
		write-Warning  "Erreur --> Les arguments -Name, -Firstname, -Grp, et -Type sont obligatoire."
		write-host "Veuillez consulter l'aide par get-help .\CreateUser.ps1 -full"
	}
	Else
	{
		$LDAP_Name,$LDAP_FirstName,$LDAP_Initials,$LDAP_CN,$LDAP_Mail,$LDAP_Login,$LDAP_Password = CreateLdapValues $Name $FirstName
		Write-Verbose "Lancement de la creation ..."
		write-host "-----------------------------------------------------"
		write-host "Voici un recapitulatif des données de l'utilisateur :" -foregroundcolor Magenta
		write-host "-----------------------------------------------------"
		write-host "Nom : $LDAP_Name"           
		write-host "Prenom : $LDAP_FirstName"
		write-host "Initials : $LDAP_Initials"
		write-host "Common Name : $LDAP_CN"
		write-host "Adresse Mail : $LDAP_Mail"
		If ($LDAP_Office -eq "")
		{
			write-host "Bureau : --"
		}
		Else
		{
			write-host "Bureau : $LDAP_Office"
		}
		write-host "Login : $LDAP_Login"
		If ($LDAP_AccountExpirationDate -eq "")
		{
			write-host "Date d'expiration du compte : --"
		}
		Else
		{
			write-host "Date d'expiration du compte : $LDAP_AccountExpirationDate"
		}
		write-host "Groupes par default : GG-DES-$Grp"
		write-host "GG-DES_$Type"
		If ($(!$TabRight.length))
		{
			write-host "Groupes additionnel : --"
		}
		Else
		{ 
			write-host "Groupes additionnel : "
			foreach ($Right in $TabRight)
			{
				write-host "$Right"
			}
		}
		write-host "-----------------------------------------------------"
		write-host ""
		Write-Verbose "Lancement de la creation ..."
		CreateAccount $LDAP_Name $LDAP_FirstName $LDAP_Initials $LDAP_CN $LDAP_Mail $LDAP_Office $LDAP_Login $LDAP_Password $Grp $AccountExpirationDate
		Addgroup $Grp $LDAP_Login $Type $AddGrps
		CreateFolders $LDAP_Login
		CreateMail $LDAP_CN $LDAP_Login $LDAP_Password $LDAP_AccountExpirationDate $LDAP_Office
		$GeneratedUID = GenerateUID
        Set-ADUser -Identity $LDAP_Login -replace @{uidnumber = $GeneratedUID}
		Set-ADUser -Identity $LDAP_Login -replace @{gidnumber = $Gid}
		$command = "/root/scripts/createDirectory_afterNIS.sh $LDAP_Login"
		plink.exe -ssh -l root -pw install filer2 $command
		Write-Verbose "Fin d'execution du script"
	}
}
Write-Host "Pressez une touche pour quitter ..." -foregroundcolor "magenta"
$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

