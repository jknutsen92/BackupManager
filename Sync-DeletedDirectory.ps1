function Sync-DeletedDirectory($TargetDirectory, $BackupDirectory, $Config, $SENTINEL_FILE) {
    $units = $Config.Config.FileRetention.DeleteBackupAfterTargetDeleted.unit
    $value = $Config.Config.FileRetention.DeleteBackupAfterTargetDeleted."#text"

    if (Test-Path -Path "$BackupDirectory\$SENTINEL_FILE") {
        $sentinelMT = (Get-Item -Path "$BackupDirectory\$SENTINEL_FILE").LastWriteTime
        switch ($units) {
            "Days" { $deletePeriod = New-TimeSpan -Days $value }
        }
        $now = Get-Date
        $deleteTime = $sentinelMT + $deletePeriod
        if ($now -ge $deleteTime) {
            Remove-Item -Path $BackupDirectory -Recurse
            Write-Log -Level INFO "Deleted backup $BackupDirectory after staling for $value $units"
        }
        else {
            Write-Log -Level WARNING "$BackupDirectory will be deleted on $deleteTime"
        }
    }
    else {
        Write-Log -Level INFO "Target directory $TargetDirectory was emptied or deleted"
        New-Item -Path "$BackupDirectory\$SENTINEL_FILE" -ItemType File
        Write-Log -Level WARNING "$BackupDirectory will be deleted from backup after $value $units"
    }
}