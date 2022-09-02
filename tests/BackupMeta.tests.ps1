BeforeAll {
    Import-Module "$env:Projects\Powershell\BackupManager\BackupMeta.psm1" -Force
    $TEST_ROOT  = "$env:TEMP\UnitTest-BackupMeta"
    $BACKUP_DIR = "$TEST_ROOT\Backup"
    $TARGET_DIR = "$TEST_ROOT\Target"
    New-Item -Path $TEST_ROOT -ItemType Directory
    New-Item -Path $BACKUP_DIR -ItemType Directory
    New-Item -Path $TARGET_DIR -ItemType Directory
}

Describe "New-Meta" {
    BeforeAll {
        $metaPath = "$TEST_ROOT\test.xml"
        New-Meta $metaPath "TEST"
        [xml]$xml = Get-Content $metaPath
        [void]$xml#Linting is annoying
    }
    It "Meta XML documents exists" {
        $metaPath | Should -Exist
    }
    It "Meta XML header declaration is correct" {
        $xml.xml | Should -Be "version=`"1.0`" encoding=`"UTF-8`""
    }
    It "Root element exists" {
        $xml.Meta | Should -BeOfType System.Xml.XmlElement
    }
    It "Root element has correct attributes" {
        $xml.Meta.BackupName | Should -Be "TEST"
    }
    AfterAll {
        Remove-Item -Path $metaPath
    }
}

Describe "Add-DeletedItemToMeta" {
    BeforeAll {
        $metaPath = "$TEST_ROOT\test.xml"
        New-Meta $metaPath "TEST"
    }
    it "DeletedItem is correct" {
        $nowDT = (Get-Date).ToString()
        $backupPath = $BACKUP_DIR
        $targetPath = $TARGET_DIR
        Add-DeletedItemToMeta $metaPath $nowDT $backupPath $targetPath

        [xml]$xml = Get-Content -Path $metaPath
        ($xml.Meta.DeletedItems.DeletedItem | Measure-Object).Count | Should -Be 1

        $deletedItem = $xml.Meta.DeletedItems.DeletedItem
        $deletedItem.TimeDeleted | Should -Be $nowDt
        $deletedItem.PathInTarget | Should -Be $targetPath
        $deletedItem."#text" | Should -Be $backupPath
    }
    it "Duplicate DeletedItem is ignored" {
        $nowDT = (Get-Date).ToString()
        $backupPath = $BACKUP_DIR
        $targetPath = $TARGET_DIR
        Add-DeletedItemToMeta $metaPath $nowDT $backupPath $targetPath

        [xml]$xml = Get-Content -Path $metaPath
        ($xml.Meta.DeletedItems.DeletedItem | Measure-Object).Count | Should -Be 1
    }
    it "Distinct DeletedItem is added properly" {
        $nowDT = (Get-Date).ToString()
        $backupPath = "$TEST_ROOT\test.xml"
        $targetPath = $TARGET_DIR
        Add-DeletedItemToMeta $metaPath $nowDT $backupPath $targetPath

        [xml]$xml = Get-Content -Path $metaPath
        ($xml.Meta.DeletedItems.DeletedItem | Measure-Object).Count | Should -Be 2

        $newDeletedItem = $xml.Meta.DeletedItems.DeletedItem[1]
        $newDeletedItem."#text" | Should -Be $backupPath
        $newDeletedItem.PathInTarget | Should -Be $targetPath
        $newDeletedItem.TimeDeleted | Should -Be $nowDT
    }
    AfterAll {
        Remove-Item -Path $metaPath
    }
}

Describe "Assert-MetaDeletedItem" {
    BeforeAll {
        $metaPath = "$TEST_ROOT\test.xml"
        New-Meta $metaPath "TEST"
    }
    it "Returns false for empty meta file" {
        Assert-MetaDeletedItem $metaPath "." | Should -BeFalse
    }
    it "Returns true for corresponding deleted item" {
        $backupPath = $BACKUP_DIR
        $targetPath = $TARGET_DIR
        Add-DeletedItemToMeta $metaPath (Get-Date) $backupPath $targetPath

        Assert-MetaDeletedItem $metaPath $backupPath | Should -BeTrue
    }
    it "Returns false for nonexistent deleted item" {
        Assert-MetaDeletedItem $metaPath "$BACKUP_DIR\1" | Should -BeFalse
    }
    AfterAll {
        Remove-Item -Path $metaPath
    }
}

Describe "Search-XmlDeletedItem" {
    BeforeAll {
        $metaPath = "$TEST_ROOT\test.xml"
        New-Meta $metaPath "TEST"
    }
    it "Empty meta file returns null" {
        [xml]$xml = Get-Content -Path $metaPath
        Search-XmlDeletedItem $xml "." | Should -Be $null
    }
    it "Correctly finds a DeletedItem in meta" {
        $nowDT = (Get-Date).ToString()
        Add-DeletedItemToMeta $metaPath $nowDT $BACKUP_DIR $TARGET_DIR
        [xml]$xml = Get-Content -Path $metaPath
        
        $target = Search-XmlDeletedItem $xml $BACKUP_DIR
        $target | Should -Not -Be $null
        $target."#text" | Should -Be $BACKUP_DIR
        $target.TimeDeleted | Should -Be $nowDT
        $target.PathInTarget | Should -Be $TARGET_DIR
    }
    it "Correctly returns null when searching for nonexistent deleted item" {
        [xml]$xml = Get-Content -Path $metaPath
        Search-XmlDeletedItem $xml "INVALID" | Should -Be $null
    }
    AfterAll {
        Remove-Item -Path $metaPath
    }
}

Describe "Remove-DeletedItemFromMeta" {
    BeforeAll {
        $metaPath = "$TEST_ROOT\test.xml"
        New-Meta $metaPath "TEST"
        $subDir = "$BACKUP_DIR\SUB"
        New-Item -Path "$subDir" -ItemType Directory
        New-Item -Path "$subDir\a.txt" -ItemType File
        New-Item -Path "$subDir\b.txt" -ItemType File
        New-Item -Path "$subDir\c.txt" -ItemType File

        $nowDT = (Get-Date).ToString()
        Add-DeletedItemToMeta $metaPath $nowDT "$subDir\a.txt" $TARGET_DIR
        Add-DeletedItemToMeta $metaPath $nowDT "$subDir\b.txt" $TARGET_DIR
        Add-DeletedItemToMeta $metaPath $nowDT "$subDir\c.txt" $TARGET_DIR
    }
    it "Correctly removes only target DeletedItem" {
        Remove-DeletedItemFromMeta $metaPath "$subDir\b.txt"

        Assert-MetaDeletedItem $metaPath "$subDir\a.txt" | Should -BeTrue
        Assert-MetaDeletedItem $metaPath "$subDir\b.txt" | Should -BeFalse
        Assert-MetaDeletedItem $metaPath "$subDir\c.txt" | Should -BeTrue
    }
    it "Makes no changes when target is nonexistent" {
        Remove-DeletedItemFromMeta $metaPath "$subDir\d.txt"

        Assert-MetaDeletedItem $metaPath "$subDir\a.txt" | Should -BeTrue
        Assert-MetaDeletedItem $metaPath "$subDir\b.txt" | Should -BeFalse
        Assert-MetaDeletedItem $metaPath "$subDir\c.txt" | Should -BeTrue
    }
    It "Attempting to remove an element again does nothing" {
        Remove-DeletedItemFromMeta $metaPath "$subDir\b.txt"

        Assert-MetaDeletedItem $metaPath "$subDir\a.txt" | Should -BeTrue
        Assert-MetaDeletedItem $metaPath "$subDir\b.txt" | Should -BeFalse
        Assert-MetaDeletedItem $metaPath "$subDir\c.txt" | Should -BeTrue
    }
    AfterAll {
        Remove-Item -Path $metaPath
        Remove-Item -Path $subDir -Recurse
    }
}

Describe "Get-DeletedItemsFromMeta" {
    BeforeAll {
        $metaPath = "$TEST_ROOT\test.xml"
        New-Meta $metaPath "TEST"
        $nowDT = (Get-Date).ToString()
        Add-DeletedItemToMeta $metaPath $nowDt $BACKUP_DIR $TARGET_DIR
        Add-DeletedItemToMeta $metaPath $nowDT $metaPath $TARGET_DIR
    }
    it "Correctly returns array of objects containing 'PathInBackup,' 'PathInTarget,' and 'TimeDeleted'" {
        $backupDirs = $BACKUP_DIR, $metaPath
        $targetDirs = $TARGET_DIR, $TARGET_DIR
        $DTs = $nowDT, $nowDT

        $deletedItems = Get-DeletedItemsFromMeta $metaPath
        $deletedItems.PathInBackup | Should -Be $backupDirs
        $deletedItems.PathInTarget | Should -Be $targetDirs
        $deletedItems.TimeDeleted | Should -Be $DTs
    }
    AfterAll {
        Remove-Item -Path $metaPath
    }
}

Describe "Set-TimeDeleted" {
    BeforeAll {
        $metaPath = "$TEST_ROOT\test.xml"
        New-Meta $metaPath "TEST"
        $nowDT = (Get-Date).ToString()
        $beforeDT = ((Get-Date) - (New-TimeSpan -Days 10)).ToString()
        Add-DeletedItemToMeta $metaPath $nowDt $BACKUP_DIR $TARGET_DIR
    }
    it "TimeDeleted is correctly modified" {
        $deletedItem = (Get-DeletedItemsFromMeta $metaPath)[0]
        $deletedItem.TimeDeleted | Should -Be $nowDT

        Set-TimeDeleted $metaPath $BACKUP_DIR $beforeDT

        $deletedItem = (Get-DeletedItemsFromMeta $metaPath)[0]
        $deletedItem.TimeDeleted | Should -Be $beforeDT
    }
    AfterAll {
        Remove-Item -Path $metaPath
    }
}

AfterAll {
    Remove-Item -Path $TEST_ROOT -Recurse
}