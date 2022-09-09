BeforeAll {
    $APP_DIR =      "$env:Projects\Powershell\BackupManager"
    $META =         "$APP_DIR\meta\Target.xml"
    $TEST_ROOT =    "$env:TEMP\BackupManagerTest"
    $TARGET_DIR =   "$TEST_ROOT\Target"
    $BACKUP_DIR =   "$TEST_ROOT\Backups"
    
    New-Item -Path $TEST_ROOT -ItemType Directory
    New-Item -Path $TARGET_DIR -ItemType Directory
    New-Item -Path $BACKUP_DIR -ItemType Directory

    [xml]$xml = Get-Content -Path "$APP_DIR\config.xml"
    $value = [int]$xml.Config.FileRetention.DeleteBackupAfterTargetDeleted."#text"
    $unit = $xml.Config.FileRetention.DeleteBackupAfterTargetDeleted.unit
    switch ($unit) {
        "Days" { $DELETE_TS = New-TimeSpan -Days $value }
    }
    $DELETE_TS
}

Describe "Backup-Directories" {
    BeforeAll {
        
    }
    it "Backup creates empty directory in \backups\ for target" {
        
    }
    it "Backup copies 3 files to backup correctly" {
        
    }
    it "Updated files in target are copied over to the backup" {
        
    }
    it "Removed files are scheduled for deletion" {
        
    }
    it "Restored files are unscheduled for deletion" {
        
    }
    it "Files that overwrite deleted files are unscheduled for deletion and updated" {
        
    }
    it "Files that exceed their stale duration are deleted" {
        
    }
    it "Entire target directory deleted triggers entire directory deletion scheduling in backup" {
        
    }
    it "Directory in backup is deleted after staling" {
        
    }
}

AfterAll {
    Remove-Item -Path $TEST_ROOT -Recurse
    Remove-Item -Path "$APP_DIR\meta\Target.xml"
}