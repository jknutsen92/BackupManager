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
}

Describe "Backup-Directories" {
    BeforeAll {
        #### Initial Filesystem ####
        # Target
        $dirTarget_1 = "A"
        $dirTarget_2 = "B"
        $dirTarget_3 = "C"
        $fileTarget_1 = "a.txt"; $fileTarget_1_Content = "Lorem ipsum dolor sit amet. Eum nesciunt accusantium ut doloribus dolores eos error error et quia natus."
        $fileTarget_2 = "b.txt"; $fileTarget_2_Content = "Qui quisquam nobis non assumenda illo nam excepturi sequi et quibusdam numquam hic animi quis."
        $fileTarget_3 = "c.txt"; $fileTarget_3_Content = "t laborum repudiandae ad optio officiis est esse quis ut autem rerum. Et repellat facere id deserunt Quis ut nihil aspernatur non optio blanditiis et molestiae rerum est praesentium sint."
        # Target\A
        $dirA_1 = "D"
        $fileA_1 = "a.txt"; $fileA_1_Content = "Ut blanditiis facilis ad consequatur doloribus in fuga similique et quia minus aut impedit dolorem sit culpa maiores sed doloremque natus."
        $fileA_2 = "b.txt"; $fileA_2_Content = "Est minima magnam At totam dignissimos aut optio aliquam"
        # Target\B
        $dirB_1 = "E"
        $dirB_2 = "F"
        $fileB_1 = "a.txt"; $fileB_1_Content = "At repudiandae ducimus est delectus quisquam qui architecto voluptatum aut fuga temporibus quo cumque molestiae est voluptatum esse."
        $fileB_2 = "b.txt"; $fileB_2_Content = "Eos placeat minus et temporibus fuga vel numquam tempora ea itaque commodi eos dolorem sint."
        $fileB_3 = "c.txt"; $fileB_3_Content = "Sed fugiat illum est repudiandae sequi qui fugiat vero ut accusamus maiores et galisum fugiat sed inventore eaque aut sint assumenda."
        # Target\B\E
        $dirE_1 = "G"
        $fileE_1 = "a.txt"; $fileE_1_Content = "asd"

        #### Added Items ####
        # Test 2
        $fileTarget_4 = "new.txt"; $fileTarget_4_Content = "iusto est tempore error et quod omnis At deleniti sint in voluptates inventore est iure aperiam. Hic nihil delectus quo neque omnis ut ipsum id voluptates"
        $fileC_1 = "12+,_a.txt"; $fileC_1_Content = "Sit eligendi saepe a amet aperiam quo quasi dicta. Id nihil doloremque qui consequatur vero in delectus nisi et recusandae consequatur."
        $fileE_2 = "!@#$%^&^()+-=',`~;.txt"; $fileE_2_Content = "Et exercitationem placeat ut culpa fugit qui illo eligendi."
        # Test 3
        $dirC_1 = "!@#$%^&^()+-=',`~;"

        #### Misc ####
        $updatedContent = "This is some updated content."
    }
    it "Creates initial directory in backup for target" {
        # Init Target
        New-Item -Path "$TARGET_DIR\$dirTarget_1" -ItemType Directory
        New-Item -Path "$TARGET_DIR\$dirTarget_2" -ItemType Directory
        New-Item -Path "$TARGET_DIR\$dirTarget_3" -ItemType Directory
        $fileTarget_1_Content | Out-File "$TARGET_DIR\$fileTarget_1"
        $fileTarget_2_Content | Out-File "$TARGET_DIR\$fileTarget_2"
        $fileTarget_3_Content | Out-File "$TARGET_DIR\$fileTarget_3"
        # Init Target\A
        New-Item -Path "$TARGET_DIR\$dirTarget_1\$dirA_1" -ItemType Directory
        $fileA_1_Content | Out-File "$TARGET_DIR\$dirTarget_1\$fileA_1"
        $fileA_2_Content | Out-File "$TARGET_DIR\$dirTarget_1\$fileA_2"
        # Init Target\B
        New-Item -Path "$TARGET_DIR\$dirTarget_2\$dirB_1" -ItemType Directory
        New-Item -Path "$TARGET_DIR\$dirTarget_2\$dirB_2" -ItemType Directory
        $fileB_1_Content | Out-File "$TARGET_DIR\$dirTarget_2\$fileB_1"
        $fileB_2_Content | Out-File "$TARGET_DIR\$dirTarget_2\$fileB_2"
        $fileB_3_Content | Out-File "$TARGET_DIR\$dirTarget_2\$fileB_3"
        # Init Target\B\E
        New-Item -Path "$TARGET_DIR\$dirTarget_2\$dirB_1\$dirE_1" -ItemType Directory
        $fileE_1_Content | Out-File "$TARGET_DIR\$dirTarget_2\$dirB_1\$fileE_1"

        &"$APP_DIR\Backup-Directories.ps1" -Test

        # Test that directory/files are copied correctly
        "$BACKUP_DIR\Target"                                | Should -Exist
        "$BACKUP_DIR\Target\$dirTarget_1"                   | Should -Exist
        "$BACKUP_DIR\Target\$dirTarget_2"                   | Should -Exist
        "$BACKUP_DIR\Target\$dirTarget_3"                   | Should -Exist
        "$BACKUP_DIR\Target\$fileTarget_1"                  | Should -Exist
        "$BACKUP_DIR\Target\$fileTarget_2"                  | Should -Exist
        "$BACKUP_DIR\Target\$fileTarget_3"                  | Should -Exist
        "$BACKUP_DIR\Target\$dirTarget_1\$dirA_1"           | Should -Exist
        "$BACKUP_DIR\Target\$dirTarget_1\$fileA_1"          | Should -Exist
        "$BACKUP_DIR\Target\$dirTarget_1\$fileA_2"          | Should -Exist
        "$BACKUP_DIR\Target\$dirTarget_2\$dirB_1"           | Should -Exist
        "$BACKUP_DIR\Target\$dirTarget_2\$dirB_2"           | Should -Exist
        "$BACKUP_DIR\Target\$dirTarget_2\$fileB_1"          | Should -Exist
        "$BACKUP_DIR\Target\$dirTarget_2\$fileB_2"          | Should -Exist
        "$BACKUP_DIR\Target\$dirTarget_2\$fileB_3"          | Should -Exist
        "$BACKUP_DIR\Target\$dirTarget_2\$dirB_1\$dirE_1"   | Should -Exist
        "$BACKUP_DIR\Target\$dirTarget_2\$dirB_1\$fileE_1"  | Should -Exist
        # Test that file content copied correctly
        Get-Content -Path "$BACKUP_DIR\Target\$fileTarget_1"                    | Should -Be $fileTarget_1_Content
        Get-Content -Path "$BACKUP_DIR\Target\$fileTarget_2"                    | Should -Be $fileTarget_2_Content
        Get-Content -Path "$BACKUP_DIR\Target\$fileTarget_3"                    | Should -Be $fileTarget_3_Content
        Get-Content -Path "$BACKUP_DIR\Target\$dirTarget_1\$fileA_1"            | Should -Be $fileA_1_Content
        Get-Content -Path "$BACKUP_DIR\Target\$dirTarget_1\$fileA_2"            | Should -Be $fileA_2_Content
        Get-Content -Path "$BACKUP_DIR\Target\$dirTarget_2\$fileB_1"            | Should -Be $fileB_1_Content
        Get-Content -Path "$BACKUP_DIR\Target\$dirTarget_2\$fileB_2"            | Should -Be $fileB_2_Content
        Get-Content -Path "$BACKUP_DIR\Target\$dirTarget_2\$fileB_3"            | Should -Be $fileB_3_Content
        Get-Content -Path "$BACKUP_DIR\Target\$dirTarget_2\$dirB_1\$fileE_1"    | Should -Be $fileE_1_Content

        # Test that meta file is correct
        [xml]$xmlDocument = Get-Content -Path $META
        $xmlDocument                                        | Should -Not -Be $null
        $xmlDocument.Meta                                   | Should -Not -Be $null
        $xmlDocument.Meta.BackupName                        | Should -Be "Target"
        $xmlDocument.Meta.Root                              | Should -Be $TARGET_DIR
        $xmlDocument.Meta.TargetDeleted                     | Should -Be "False"
        $xmlDocument.Meta.DirectoryTree                     | Should -Not -Be $null
        $te = $xmlDocument.Meta.DirectoryTree.Target
        $te                                                 | Should -Not -Be $null
        $te.__DeletedItems__                                | Should -Not -Be $null
        $te.$dirTarget_1                                    | Should -Not -Be $null
        $te.$dirTarget_1.__DeletedItems__                   | Should -Not -Be $null
        $te.$dirTarget_1.$dirA_1                            | Should -Not -Be $null
        $te.$dirTarget_1.$dirA_1.__DeletedItems__           | Should -Not -Be $null
        $te.$dirTarget_2                                    | Should -Not -Be $null
        $te.$dirTarget_2.__DeletedItems__                   | Should -Not -Be $null
        $te.$dirTarget_2.$dirB_1                            | Should -Not -Be $null
        $te.$dirTarget_2.$dirB_1.__DeletedItems__           | Should -Not -Be $null
        $te.$dirTarget_2.$dirB_1.$dirE_1                    | Should -Not -Be $null
        $te.$dirTarget_2.$dirB_1.$dirE_1.__DeletedItems__   | Should -Not -Be $null
        $te.$dirTarget_2.$dirB_2                            | Should -Not -Be $null
        $te.$dirTarget_2.$dirB_2.__DeletedItems__           | Should -Not -Be $null
        $te.$dirTarget_3                                    | Should -Not -Be $null
        $te.$dirTarget_3.__DeletedItems__                   | Should -Not -Be $null
    }
    it "Copies 3 files to backup correctly" {
        $fileTarget_4_Content   | Out-File -Path "$TARGET_DIR\$fileTarget_4"
        $fileC_1_Content        | Out-File -Path "$TARGET_DIR\$dirTarget_3\$fileC_1"
        $fileE_2_Content        | Out-File -Path "$TARGET_DIR\$dirTarget_2\$dirB_1\$fileE_2"

        &"$APP_DIR\Backup-Directories.ps1" -Test

        # Test that directory/files are copied correctly
        "$BACKUP_DIR\Target\$fileTarget_4"                      | Should -Exist
        "$BACKUP_DIR\Target\$dirTarget_3\$fileC_1"              | Should -Exist
        "$BACKUP_DIR\Target\$dirTarget_2\$dirB_1\$fileE_2"      | Should -Exist
        # Test that file content copied correctly
        Get-Content -Path "$BACKUP_DIR\Target\$fileTarget_4"                    | Should -Be $fileTarget_4_Content
        Get-Content -Path "$BACKUP_DIR\Target\$dirTarget_3\$fileC_1"            | Should -Be $fileC_1_Content
        Get-Content -Path "$BACKUP_DIR\Target\$dirTarget_2\$dirB_1\$fileE_2"    | Should -Be $fileE_2_Content
    }
    it "Copies new directory in target to backup" {
        New-Item -Path "$TARGET_DIR\$dirTarget_3\$dirC_1" -ItemType Directory

        &"$APP_DIR\Backup-Directories.ps1" -Test

        # Test that directory copied correctly
        "$BACKUP_DIR\Target\$dirTarget_3\$dirC_1"                   | Should -Exist

        # Test that meta file is correct
        [xml]$xmlDocument = Get-Content -Path $META
        $xmlElementName = Get-ValidXmlDirectoryName $dirC_1
        $xmlDocument.Meta.DirectoryTree.Target.C.$xmlElementName    | Should -Not -Be $null
    }
    it "Updated files in target are copied over to the backup" {
        Start-Sleep -Seconds 1
        Set-Content -Path "$TARGET_DIR\$dirTarget_2\$fileB_2"   -Value $updatedContent
        Set-Content -Path "$TARGET_DIR\$fileTarget_1"           -Value $updatedContent

        &"$APP_DIR\Backup-Directories.ps1" -Test

        Get-Content -Path "$BACKUP_DIR\Target\$dirTarget_2\$fileB_2"    | Should -Be $updatedContent
        Get-Content -Path "$BACKUP_DIR\Target\$fileTarget_1"            | Should -Be $updatedContent
    }
    it "Removed files are scheduled for deletion" {
        Remove-Item -Path "$TARGET_DIR\$dirTarget_2\$fileB_2" 
        Remove-Item -Path "$TARGET_DIR\$dirTarget_2\$dirB_1\$fileE_1"
        
        &"$APP_DIR\Backup-Directories.ps1" -Test

        "$BACKUP_DIR\Target\$dirTarget_2\$fileB_2"          | Should -Exist
        "$BACKUP_DIR\Target\$dirTarget_2\$dirB_1\$fileE_1"  | Should -Exist

        [xml]$xmlDocument = Get-Content -Path $META
        $nowDT = Get-Date

        $b2DeletedItem = $xmlDocument.Meta.DirectoryTree.Target.B.__DeletedItems__.__DeletedItem__
        $b2DeletedItem | Should -Not -Be $null
        $b2DeletedItem.Name     | Should -Be $fileB_2
        $b2DeletedDT = [DateTime]$b2DeletedItem.TimeDeleted
        $nowDT -ge $b2DeletedDT | Should -BeTrue

        $e1DeletedItem = $xmlDocument.Meta.DirectoryTree.Target.B.E.__DeletedItems__.__DeletedItem__
        $e1DeletedItem | Should -Not -Be $null
        $e1DeletedItem.Name     | Should -Be $fileE_1
        $e1DeletedDT = [DateTime]$e1DeletedItem.TimeDeleted
        $nowDT -ge $e1DeletedDT | Should -BeTrue
    }
    it "Restored files are unscheduled for deletion and updated if changed" {
        $restoredContent = "I am a restored file"
        $restoredContent | Out-File "$TARGET_DIR\$dirTarget_2\$fileB_2"
        $restoredContent | Out-File "$TARGET_DIR\$dirTarget_2\$dirB_1\$fileE_1"

        &"$APP_DIR\Backup-Directories.ps1" -Test

        $b2DeletedItem = $xmlDocument.Meta.DirectoryTree.Target.B.__DeletedItems__.__DeletedItem__
        $b2DeletedItem | Should -Be $null
        Get-Content -Path "$BACKUP_DIR\Target\$dirTarget_2\$fileB_2" | Should -Be $restoredContent

        $e1DeletedItem = $xmlDocument.Meta.DirectoryTree.Target.B.E.__DeletedItems__.__DeletedItem__
        $e1DeletedItem | Should -Be $null
        Get-Content -Path "$BACKUP_DIR\Target\$dirTarget_2\$dirB_1\$fileE_1" | Should -Be $restoredContent
    }
    it "Files that exceed their stale duration are deleted" {
        Remove-Item -Path "$TARGET_DIR\$fileTarget_3"
        Remove-Item -Path "$TARGET_DIR\$dirTarget_1\$fileA_2"

        &"$APP_DIR\Backup-Directories.ps1" -Test

        # Update deleted items in meta file
        [xml]$xmlDocument = Get-Content -Path $Meta

        $t3DeletedItem = $xmlDocument.Meta.DirectoryTree.Target.__DeletedItems__.__DeletedItem__
        $t3DeletedItem | Should -Not -Be $null
        $deletedDT = [DateTime]$t3DeletedItem.TimeDeleted
        $expireDT = $deletedDT - $DELETE_TS
        $t3DeletedItem.TimeDeleted = $expireDT.ToString()

        $a2DeletedItem = $xmlDocument.Meta.DirectoryTree.Target.A.__DeletedItems__.__DeletedItem__
        $a2DeletedItem | Should -Not -Be $null
        $a2DeletedItem.TimeDeleted = $expireDT.ToString()

        $xmlDocument.Save($Meta)

        &"$APP_DIR\Backup-Directories.ps1" -Test

        # Check that files are deleted
        "$BACKUP_DIR\Target\$fileTarget_3"          | Should -Not -Exist
        "$BACKUP_DIR\Target\$dirTarget_1\$fileA_2"  | Should -Not -Exist

        [xml]$xmlDocument = Get-Content -Path $Meta
        $xmlDocument.Meta.DirectoryTree.Target.__DeletedItems__.__DeletedItem__     | Should -Be $null
        $xmlDocument.Meta.DirectoryTree.Target.A.__DeletedItems__.__DeletedItem__   | Should -Be $null
    }
    it "Deleted directory and children are deleted after staling past expiration time" {
        Remove-Item -Path "$TARGET_DIR\$dirTarget_2\$dirB_1" -Recurse

        &"$APP_DIR\Backup-Directories.ps1" -Test

        "$BACKUP_DIR\Target\$dirTarget_2\$dirB_1" | Should -Exist

        [xml]$xmlDocument = Get-Content -Path $Meta
        $deletedDir = $xmlDocument.Meta.DirectoryTree.Target.B.__DeletedItems__.__DeletedItem__
        $deletedDir | Should -Not -Be $null
        $deletedDT = [DateTime]$deletedDir.TimeDeleted
        $expireDT = $deletedDT - $DELETE_TS
        $deletedDir.TimeDeleted = $expireDT.ToString()
        $xmlDocument.Save($META)

        &"$APP_DIR\Backup-Directories.ps1" -Test

        "$BACKUP_DIR\Target\$dirTarget_2\$dirB_1"           | Should -Not -Exist
        "$BACKUP_DIR\Target\$dirTarget_2\$dirB_1\$dirE_1"   | Should -Not -Exist
        "$BACKUP_DIR\Target\$dirTarget_2\$dirB_1\$fileE_1"  | Should -Not -Exist
        "$BACKUP_DIR\Target\$dirTarget_2\$dirB_1\$fileE_2"  | Should -Not -Exist

        [xml]$xmlDocument = Get-Content -Path $META
        $deletedDir = $xmlDocument.Meta.DirectoryTree.Target.B.__DeletedItems__.__DeletedItem__
        $deletedDir     | Should -Be $null
        $deletedDir.E   | Should -Be $null
    }
    it "Entire target directory deleted triggers entire directory deletion scheduling in backup" {
        Remove-Item $TARGET_DIR -Recurse

        &"$APP_DIR\Backup-Directories.ps1" -Test

        [xml]$xmlDocument = Get-Content -Path $META
        [Boolean]$xmlDocument.Meta.TargetDeleted    | Should -BeTrue
        $xmlDocument.Meta.TimeDeleted               | Should -Not -Be $null
    }
    it "Directory in backup is deleted after staling" {
        [xml]$xmlDocument = Get-Content -Path $META
        $timeDeleted = [DateTime]$xmlDocument.Meta.TimeDeleted
        $expirationDT = $timeDeleted - $DELETE_TS
        $xmlDocument.Meta.TimeDeleted = $expirationDT.ToString()
        $xmlDocument.Save($META)

        &"$APP_DIR\Backup-Directories.ps1" -Test

        "$BACKUP_DIR\Target"        | Should -Not -Exist
        $META                       | Should -Not -Exist
    }
}

AfterAll {
    Remove-Item -Path $TEST_ROOT -Recurse
    Remove-Item -Path "$APP_DIR\meta\Target.xml"
}