Import-Module ".\BackupMeta.psm1" -Force

function Confirm-DeletedItems($Meta, $Config) {
    $value = [int]$Config.Config.FileRetention.DeleteBackupAfterTargetDeleted."#text"
    $unit = $Config.Config.FileRetention.DeleteBackupAfterTargetDeleted.unit
    switch ($unit) {
        "Days" { $deletePeriod = New-TimeSpan -Days $value }
    }
    $nowDT = Get-Date

    $deletedItems = Get-DeletedItemsFromMeta $Meta
    foreach ($deletedItem in $deletedItems) {
        $backupPath = $deletedItem.PathInBackup
        $targetPath = $deletedItem.PathInTarget
        $timeDeleted = $deletedItem.TimeDeleted

        if (Test-Path -Path $targetPath) {
            Write-Log -Level INFO "$targetPath has been restored or overwritten"
            Remove-DeletedItemsFromMeta $Meta $backupPath
            Write-Log -Level INFO "$backupPath has been removed from deleted items in meta file"
        }
        elseif ($nowDT -ge ($deletePeriod + $timeDeleted)) {
            Write-Log -Level INFO "$backupPath has expired and will be deleted"
            Remove-Item -Path $backupPath
            Write-Log -Level INFO "$backupPath deleted"
        }
        else {
            Write-Log -Level WARNING "$backupPath will be deleted after $($deletePeriod + $timeDeleted)"
        }
    }
}