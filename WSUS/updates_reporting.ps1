[reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration") 
$wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer()
$wsus.GetComputerTargetGroups() | ForEach {
    $Group = $_.Name
    $_.GetTotalSummary() | ForEach {
        [pscustomobject]@{
            TargetGroup = $Group
            Needed = ($_.NotInstalledCount + $_.DownloadedCount)
            "Installed/NotApplicable" = ($_.NotApplicableCount + $_.InstalledCount)
            NoStatus = $_.UnknownCount
            PendingReboot = $_.InstalledPendingRebootCount
        }
    }
} |export-csv \\GROVSW1F\wsus_reports\maj_status_$((Get-Date).ToString('dd-MM-yyyy')).csv