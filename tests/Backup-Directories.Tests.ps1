BeforeAll {
    $APP_DIR =      "$env:Projects\Powershell\BackupManager"
    $TEST_ROOT =    "$env:TEMP\BackupManagerTest\"
    $TARGET_DIR =   "$TEST_ROOT\Target\"
    $BACKUP_DIR =   "$TEST_ROOT\Backups\"
    
    New-Item -Path $TEST_ROOT -ItemType Directory
    New-Item -Path $TARGET_DIR -ItemType Directory
    New-Item -Path $BACKUP_DIR -ItemType Directory
}

Describe "Backup-Directories" {
    it "Backup creates empty directory in \backups\ for target" {
        &"$APP_DIR\Backup-Directories.ps1" -Test -LogToFile
        "$BACKUP_DIR\Target" | Should -Exist
    }
}

AfterAll {
    Remove-Item -Path $TEST_ROOT -Recurse
}