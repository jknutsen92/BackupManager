function New-Meta($Path, $BackupName, $TargetDirectory) {
    if (Test-Path -Path $Path) {
        Write-Log -Level ERROR "A meta file for $Path already exists"
        Wait-Logging
        return
    }
    [xml]$xml = New-Object System.Xml.XmlDocument

    $declaration = $xml.CreateXmlDeclaration("1.0", "UTF-8", $null)
    [void]$xml.AppendChild($declaration)

    $root = $xml.CreateElement("Meta")
    $root.SetAttribute("BackupName", $BackupName)
    $root.SetAttribute("Root", $TargetDirectory)
    $root.SetAttribute("TargetDeleted", "False")
    [void]$xml.AppendChild($root)

    $treeElement = $xml.CreateElement("DirectoryTree")
    [void]$root.AppendChild($treeElement)

    Import-DirectoryTree $xml $treeElement $TargetDirectory

    [void]$xml.Save($Path)
}

function Import-DirectoryTree($XmlDocument, $ParentElement, $TargetDirectory) {
    $dirName = (Select-String -Pattern "\\([^\\]+)$" -InputObject $TargetDirectory).Matches.Groups[1].Value
    $dirName = Get-ValidXmlDirectoryName $dirName
    $dirElement = $XmlDocument.CreateElement($dirName)
    [void]$ParentElement.AppendChild($dirElement)
    $deletedItemsElement = $XmlDocument.CreateElement("__DeletedItems__")
    $deletedItemsElement.SetAttribute("Valid", "True")
    [void]$dirElement.AppendChild($deletedItemsElement)

    $childDirectories = Get-ChildItem -Path $TargetDirectory -Directory
    foreach ($childDirectory in $childDirectories) {
        Import-DirectoryTree $XmlDocument $dirElement $childDirectory.FullName
    }
}

function Get-ValidXmlDirectoryName($DirectoryName) {
    $xmlName = ''
    for ($i = 0; $i -lt $DirectoryName.Length; $i++) {
        switch ($DirectoryName[$i]) {
            '!' { $xmlName += '.0x21.' }
            '@' { $xmlName += '.0x40.' }
            '#' { $xmlName += '.0x23.' }
            '$' { $xmlName += '.0x24.' }
            '%' { $xmlName += '.0x25.' }
            '^' { $xmlName += '.0x5E.' }
            '&' { $xmlName += '.0x26.' }
            '(' { $xmlName += '.0x28.' }
            ')' { $xmlName += '.0x29.' }
            '+' { $xmlName += '.0x2B.' }
            '-' { $xmlName += '.0x2D.' }
            '=' { $xmlName += '.0x3D.' }
            '''' { $xmlName += '.0x27.' }
            ',' { $xmlName += '.0x2C.' }
            '`' { $xmlName += '.0x60.' }
            '~' { $xmlName += '.0x7E.' }
            '{' { $xmlName += '.0x7B.' }
            '}' { $xmlName += '.0x7D.' }
            '[' { $xmlName += '.0x5B.' }
            ']' { $xmlName += '.0x5D.' }
            ';' { $xmlName += '.0x3B.' }
            '.' { $xmlName += '.0x2E.' }
            ' ' { $xmlName += '.0x20.' }
            default { $xmlName += $DirectoryName[$i] }
        }
    }

    if (-not ($xmlName[0] -match "[a-zA-z_]")) {
        $xmlName = "_$xmlName"
    }
    return $xmlName
}

function Get-DirectoryNameFromXml($DirectoryElementName) {
    $name = ''
    
    $substrings = [regex]::split($DirectoryElementName, "\.(0x[0-9A-F]{2})\.")
    foreach ($substring in $substrings) {
        switch ($substring) {
            '0x21' { $name += '!' }
            '0x40' { $name += '@' }
            '0x23' { $name += '#' }
            '0x24' { $name += '$' }
            '0x25' { $name += '%' }
            '0x5E' { $name += '^' }
            '0x26' { $name += '&' }
            '0x28' { $name += '(' }
            '0x29' { $name += ')' }
            '0x2B' { $name += '+' }
            '0x2D' { $name += '-' }
            '0x3D' { $name += '=' }
            '0x27' { $name += '''' }
            '0x2C' { $name += ',' }
            '0x60' { $name += '`' }
            '0x7E' { $name += '~' }
            '0x7B' { $name += '{' }
            '0x7D' { $name += '}' }
            '0x5B' { $name += '[' }
            '0x5D' { $name += ']' }
            '0x3B' { $name += ';' }
            '0x2E' { $name += '.' }
            '0x20' { $name += ' ' }
            default { $name += $substring }
        }
    }

    if ($name[0] -eq '_') {
        $name = $name.Substring(1)
    }
    return $name
}

function Get-ItemNameFromAttr($XmlAttribute) {
    return $XmlAttribute.Replace("&", "&amp;")
}

function Get-AttrNameFromItem($ItemName) {
    return $ItemName.Replace("&amp;", "&")
}

function Add-DirectoryToMeta($XmlDocument, $ParentElement, $DirectoryName) {
    $DirectoryName = Get-ValidXmlDirectoryName $DirectoryName
    $alreadyExists = $null -ne $ParentElement.$DirectoryName
    if (-not $alreadyExists) {
        $newDir = $XmlDocument.CreateElement($DirectoryName)
        $newDeleted = $XmlDocument.CreateElement("__DeletedItems__")
        $newDeleted.SetAttribute("Valid", "True")
        [void]$newDir.AppendChild($newDeleted)
        [void]$ParentElement.AppendChild($newDir)
    }
}

function Remove-DirectoryFromMeta($ParentElement, $DirectoryName) {
    $DirectoryName = Get-ValidXmlDirectoryName $DirectoryName
    $toRemove = $ParentElement.$DirectoryName
    if ($null -eq $toRemove) {
        throw [System.ArgumentException]::New("$DirectoryName is not a child of $ParentElement")
    }
    $ParentElement.RemoveChild($toRemove)
}

function Add-DeletedItem($XmlDocument, $ParentElement, $ItemName) {
    $deletedItem = $XmlDocument.CreateElement("__DeletedItem__")
    $deletedItem.SetAttribute("TimeDeleted", (Get-Date).ToString())
    $deletedItem.SetAttribute("Name", (Get-AttrNameFromItem $ItemName))
    [void]$ParentElement.__DeletedItems__.AppendChild($deletedItem)
}

function Remove-DeletedItem($ParentElement, $ItemName) {
    $ItemName = Get-AttrNameFromItem $ItemName
    $deletedItem = $ParentElement.__DeletedItems__.__DeletedItem__ |
                    Where-Object -Property Name -eq  $ItemName

    if ($null -ne $deletedItem) {
        [void]$ParentElement.__DeletedItems__.RemoveChild($deletedItem)
    }
}

function Get-DeletedItems($ParentElement) {
    return $ParentElement.__DeletedItems__.__DeletedItem__
}

function Get-ChildDirectoryElement($DirectoryElement, $ChildName) {
    $xmlName = Get-ValidXmlDirectoryName $ChildName
    return $DirectoryElement.$xmlName
}