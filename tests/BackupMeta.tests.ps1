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

    AfterAll {
        Remove-Item -Path $metaPath
    }
}

AfterAll {
    Remove-Item -Path $TEST_DIR -Recurse
}