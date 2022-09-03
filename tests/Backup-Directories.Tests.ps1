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
    $Meta#Linting
}

Describe "Backup-Directories" {
    BeforeAll {
        $aFilePath =    "a.txt"
        $aFileContent = "This file is called A"
        $bFilePath =    "Sub1\b.txt"
        $bFileContent = "This file is called B"
        $cFilePath =    "Sub1\SubSub1\c.txt"
        $cFileContent = "This file is called C"

        $bUpdatedContent = "$bFileContent. I was updated!"
        $cUpdatedContent = "I am a new B"

        $aFilePath
        $aFileContent
        $bFilePath
        $cFilePath
        $cFileContent
        $bUpdatedContent
        $cUpdatedContent#linting
    }
    it "Backup creates empty directory in \backups\ for target" {
        &"$APP_DIR\Backup-Directories.ps1" -Test -LogToFile
        "$BACKUP_DIR\Target" | Should -Exist
    }
    it "Backup copies 3 files to backup correctly" {
        $aFileContent | Out-File -FilePath "$TARGET_DIR\$aFilePath"
        New-Item -Path "$TARGET_DIR\Sub1" -ItemType Directory
        $bFileContent | Out-File -FilePath "$TARGET_DIR\$bFilePath"
        New-Item -Path "$TARGET_DIR\Sub1\SubSub1" -ItemType Directory
        $cFileContent | Out-File -FilePath "$TARGET_DIR\$cFilePath"

        &"$APP_DIR\Backup-Directories.ps1" -Test -LogToFile

        "$BACKUP_DIR\Target\$aFilePath" | Should -Exist
        Get-Content "$BACKUP_DIR\Target\$aFilePath" | Should -Be $aFileContent
        "$BACKUP_DIR\Target\$bFilePath" | Should -Exist
        Get-Content "$BACKUP_DIR\Target\$bFilePath" | Should -Be $bFileContent
        "$BACKUP_DIR\Target\$cFilePath" | Should -Exist
        Get-Content "$BACKUP_DIR\Target\$cFilePath" | Should -Be $cFileContent
    }
    it "Updated files in target are copied over to the backup" {
        Set-Content -Path "$TARGET_DIR\$bFilePath" -Value $bUpdatedContent

        &"$APP_DIR\Backup-Directories.ps1" -Test -LogToFile

        Get-Content "$BACKUP_DIR\Target\$bFilePath" | Should -Be $bUpdatedContent
    }
    it "Removed files are scheduled for deletion" {
        Move-Item -Path "$TARGET_DIR\$aFilePath" -Destination "$TEST_ROOT\$aFilePath"
        Remove-Item -Path "$TARGET_DIR\$cFilePath"

        &"$APP_DIR\Backup-Directories.ps1" -Test -LogToFile

        (Get-DeletedItemsFromMeta $META).Count | Should -Be 2
        Assert-MetaDeletedItem $META "$BACKUP_DIR\Target\$aFilePath" | Should -BeTrue
        Assert-MetaDeletedItem $META "$BACKUP_DIR\Target\$cFilePath" | Should -BeTrue
    }
    it "Restored files are unscheduled for deletion" {
        Move-Item -Path "$TEST_ROOT\$aFilePath" -Destination "$TARGET_DIR\$aFilePath"

        &"$APP_DIR\Backup-Directories.ps1" -Test -LogToFile

        (Get-DeletedItemsFromMeta $META).Count | Should -Be 1
        Assert-MetaDeletedItem $META "$BACKUP_DIR\Target\$aFilePath" | Should -BeFalse
        Assert-MetaDeletedItem $META "$BACKUP_DIR\Target\$cFilePath" | Should -BeTrue
    }
    it "Files that overwrite deleted files are unscheduled for deletion and updated" {
        $cUpdatedContent | Out-File -Path "$TARGET_DIR\$cFilePath"

        &"$APP_DIR\Backup-Directories.ps1" -Test -LogToFile

        (Get-DeletedItemsFromMeta $META).Count | Should -Be 0
        Assert-MetaDeletedItem $META "$BACKUP_DIR\Target\$cFilePath" | Should -BeFalse
    }
    it "Files that exceed their stale duration are deleted" {
        $expiredDT = (Get-Date) - $DELETE_TS
        Remove-Item -Path "$TARGET_DIR\$bFilePath"

        &"$APP_DIR\Backup-Directories.ps1" -Test -LogToFile

        Assert-MetaDeletedItem $META "$BACKUP_DIR\Target\$bFilePath" | Should -BeTrue

        Set-TimeDeleted $META "$BACKUP_DIR\Target\$bFilePath" $expiredDT

        &"$APP_DIR\Backup-Directories.ps1" -Test -LogToFile

        "$BACKUP_DIR\$bFilePath" | Should -Not -Exist
        Assert-MetaDeletedItem $META "$BACKUP_DIR\Target\$bFilePath" | Should -BeFalse
    }
    it "Entire target directory deleted triggers entire directory deletion scheduling in backup" {
        #TODO: Diagnose this one
        Remove-Item -Path $TARGET_DIR -Recurse

        &"$APP_DIR\Backup-Directories.ps1" -Test -LogToFile
        
        Assert-MetaDeletedItem $META "$BACKUP_DIR\Target" | Should -BeTrue
    }
    it "Directory in backup is deleted after staling" {
        $deleted = Get-DeletedItemsFromMeta $META | Where-Object -Property PathInBackup -eq "$BACKUP_DIR\Target"
        $expiredDT = [DateTime]$deleted.TimeDeleted - $DELETE_TS
        Set-TimeDeleted $META "$BACKUP_DIR\Target" $expiredDT

        &"$APP_DIR\Backup-Directories.ps1" -Test -LogToFile

        "$BACKUP_DIR\Target\" | Should -Not -Exist
        Assert-MetaDeletedItem $META "$BACKUP_DIR\Target\" | Should -BeFalse
    }
}

AfterAll {
    Remove-Item -Path $TEST_ROOT -Recurse
    Remove-Item -Path "$APP_DIR\meta\Target.xml"
}