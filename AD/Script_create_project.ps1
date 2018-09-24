Import-module activedirectory
$nomProjet = Read-Host "Quelle est le nom du projet ? sans espaces de preference"
$nomProjet = $nomProjet.toUpper()
$sizeText = Read-Host "Quel est le quota souhaite en GB?"
$size = ([int64]($sizeText.Trim()) * [int64]1GB)

Write-host "Creation du dossier et affectation des quotas"
$command_create_quota = {
   param($nomprojet,$size)
   mkdir "j:\$nomProjet"
   New-FsrmQuota -Path "J:\$nomProjet" -Size $size
            }
Invoke-Command -ComputerName GROESSWDFS0B -ArgumentList $nomprojet,$size -ScriptBlock $command_create_quota

Write-host "Creation des OU et des groupes AD du projet"
$pathOU="ou=projets,ou=des groupes,dc=gr0vsdma,dc=rte-france,dc=com"
New-ADOrganizationalUnit -Name $nomProjet -Path $pathOU
New-ADGroup -name GL-$($nomProjet)_L -DisplayName GL-$($nomProjet)_L -GroupCategory Security -GroupScope DomainLocal -Path "ou=$nomProjet,$pathOU"
New-ADGroup -name GL-$($nomProjet)_M -DisplayName GL-$($nomProjet)_M -GroupCategory Security -GroupScope DomainLocal -Path "ou=$nomProjet,$pathOU"
New-ADGroup -Name GG-$($nomProjet)_L -DisplayName GG-$($nomProjet)_L -GroupCategory security -GroupScope Global -Path "ou=$nomProjet,$pathOU"
New-ADGroup -Name GG-$($nomProjet)_M -DisplayName GG-$($nomProjet)_M -GroupCategory security -GroupScope Global -Path "ou=$nomProjet,$pathOU"
Add-ADGroupMember -Identity GL-$($nomProjet)_L -Members GG-$($nomProjet)_L
Add-ADGroupMember -Identity GL-$($nomProjet)_M -Members GG-$($nomProjet)_M



Write-host "Application des permissions necessaires"
$command_create_permissions = {
   param($nomprojet)
   $accessControlRWGL = New-Object System.Security.AccessControl.FileSystemAccessRule("GR0VSDMA\GL-$($nomProjet)_M", "Modify", "ContainerInherit, ObjectInherit", "None", "Allow")
   $accessControlRWGG = New-Object System.Security.AccessControl.FileSystemAccessRule("GR0VSDMA\GG-$($nomProjet)_M", "Modify" , "ContainerInherit, ObjectInherit", "None", "Allow")
   $accessControlROGL = New-Object System.Security.AccessControl.FileSystemAccessRule("GR0VSDMA\GL-$($nomProjet)_L", "Read", "ContainerInherit, ObjectInherit", "None", "Allow")
   $accessControlROGG = New-Object System.Security.AccessControl.FileSystemAccessRule("GR0VSDMA\GG-$($nomProjet)_L", "Read", "ContainerInherit, ObjectInherit", "None", "Allow")
   $Acl = Get-Acl "J:\$nomProjet"
   $Acl.AddAccessRule($accessControlRWGL)
   $Acl.AddAccessRule($accessControlRWGG)
   $Acl.AddAccessRule($accessControlROGL)
   $Acl.AddAccessRule($accessControlROGG)
   Set-Acl "J:\$nomProjet" $Acl
  }
Invoke-Command -ComputerName GROESSWDFS0B -ArgumentList $nomprojet -ScriptBlock $command_create_permissions

Write-host "operation effectuee avec succes s'il ya pas des erreurs affichees"
