[reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration") 
 
$wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer() 
 
foreach( $group in $wsus.GetComputerTargetGroups() ) 
{ 
    Write-Host $group.Name ":" $group.GetComputerTargets().count
}
Write-Host "Total groups number" $wsus.GetComputerTargetGroups().count