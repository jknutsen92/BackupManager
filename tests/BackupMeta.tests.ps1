BeforeAll {
    Import-Module "$env:Projects\Powershell\BackupManager\BackupMeta.psm1" -Force
    $TEST_DIR = "$env:TEMP\UnitTest-BackupMeta"
    New-Item -Path $TEST_DIR -ItemType Directory -ErrorAction Ignore
}

Describe "New-Meta" {
    BeforeAll {
        $metaPath = "$TEST_DIR\test.xml"
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
        $metaPath = "$TEST_DIR\test.xml"
        New-Meta $metaPath "TEST"
    }
    it "DeletedItem is correct" {
        $nowDT = (Get-Date).ToString()
        $path = $TEST_DIR
        Add-DeletedItemToMeta $metaPath $nowDT $path

        [xml]$xml = Get-Content -Path $metaPath
        ($xml.Meta.DeletedItems.DeletedItem | Measure-Object).Count | Should -Be 1

        $deletedItem = $xml.Meta.DeletedItems.DeletedItem
        $deletedItem.TimeDeleted | Should -Be $nowDt

        $deletedItem."#text" | Should -Be $path
    }
    it "Duplicate DeletedItem is ignored" {
        $nowDT = (Get-Date).ToString()
        $path = $TEST_DIR
        Add-DeletedItemToMeta $metaPath $nowDT $path

        [xml]$xml = Get-Content -Path $metaPath
        ($xml.Meta.DeletedItems.DeletedItem | Measure-Object).Count | Should -Be 1
    }
    it "Distinct DeletedItem is added properly" {
        $nowDT = (Get-Date).ToString()
        $path = "$TEST_DIR\test.xml"
        Add-DeletedItemToMeta $metaPath $nowDT $path

        [xml]$xml = Get-Content -Path $metaPath
        ($xml.Meta.DeletedItems.DeletedItem | Measure-Object).Count | Should -Be 2

        $newDeletedItem = $xml.Meta.DeletedItems.DeletedItem[1]
        $newDeletedItem."#text" | Should -Be $path

        $newDeletedItem.TimeDeleted | Should -Be $nowDT
    }
    AfterAll {
        Remove-Item -Path $metaPath
    }
}

Describe "Assert-MetaDeletedItem" {
    BeforeAll {
        $metaPath = "$TEST_DIR\test.xml"
        New-Meta $metaPath "TEST"
    }
    it "Returns false for empty meta file" {
        Assert-MetaDeletedItem $metaPath "." | Should -BeFalse
    }
    it "Returns true for corresponding deleted item" {
        $path = $TEST_DIR
        Add-DeletedItemToMeta $metaPath (Get-Date) $path

        Assert-MetaDeletedItem $metaPath $path | Should -BeTrue
    }
    it "Returns false for nonexistent deleted item" {
        Assert-MetaDeletedItem $metaPath "$TEST_DIR\1" | Should -BeFalse
    }
    AfterAll {
        Remove-Item -Path $metaPath
    }
}

Describe "Search-XmlDeletedItem" {
    BeforeAll {
        $metaPath = "$TEST_DIR\test.xml"
        New-Meta $metaPath "TEST"
    }
    it "Empty meta file returns null" {
        [xml]$xml = Get-Content -Path $metaPath
        Search-XmlDeletedItem $xml "." | Should -Be $null
    }
    it "Correctly finds a DeletedItem in meta" {
        $nowDT = (Get-Date).ToString()
        Add-DeletedItemToMeta $metaPath $nowDT $TEST_DIR
        [xml]$xml = Get-Content -Path $metaPath
        
        $target = Search-XmlDeletedItem $xml $TEST_DIR
        $target | Should -Not -Be $null
        $target."#text" | Should -Be $TEST_DIR
        $target.TimeDeleted | Should -Be $nowDT
    }
    it "Correctly returns null when searching for nonexistent deteled item" {
        [xml]$xml = Get-Content -Path $metaPath
        Search-XmlDeletedItem $xml "INVALID" | Should -Be $null
    }
    AfterAll {
        Remove-Item -Path $metaPath
    }
}

Describe "Remove-DeletedItemFromMeta" {
    BeforeAll {
        $metaPath = "$TEST_DIR\test.xml"
        New-Meta $metaPath "TEST"
        $subDir = "$TEST_DIR\SUB"
        New-Item -Path "$subDir" -ItemType Directory
        New-Item -Path "$subDir\a.txt" -ItemType File
        New-Item -Path "$subDir\b.txt" -ItemType File
        New-Item -Path "$subDir\c.txt" -ItemType File

        $nowDT = (Get-Date).ToString()
        Add-DeletedItemToMeta $metaPath $nowDT "$subDir\a.txt"
        Add-DeletedItemToMeta $metaPath $nowDT "$subDir\b.txt"
        Add-DeletedItemToMeta $metaPath $nowDT "$subDir\c.txt"
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
        $metaPath = "$TEST_DIR\test.xml"
        New-Meta $metaPath "TEST"
        Add-DeletedItemToMeta $metaPath (Get-Date) $TEST_DIR
        Add-DeletedItemToMeta $metaPath (Get-Date) $metaPath
    }
    it "Correctly returns array of path strings" {
        $array = $TEST_DIR, $metaPath
        Get-DeletedItemsFromMeta $metaPath | Should -Be $array
    }
    AfterAll {
        Remove-Item -Path $metaPath
    }
}

AfterAll {
    Remove-Item -Path $TEST_DIR -Recurse
}