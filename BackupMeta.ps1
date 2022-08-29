function New-Meta($Path, $BackupName) {
    if (Test-Path -Path $Path) {
        Write-Log -Level ERROR "A meta file for $Path already exists"
        Wait-Logging
        return
    }
    [xml]$xml = New-Object System.Xml.XmlDocument

    $declaration = $xml.CreateXmlDeclaration("1.0", "UTF-8", $null)
    $xml.AppendChild($declaration)

    $root = $xml.CreateNode("element", "Meta", $null)
    $root.SetAttribute("BackupName", $BackupName)
    $xml.AppendChild($root)

    $deletedItems = $xml.CreateNode("element", "DeletedItems", $null)
    [void]$root.AppendChild($deletedItems)

    $xml.Save($Path)
}

function Search-MetaDeletedItem($Meta, $Path) {
    [xml]$xml = Get-Content -Path $Meta

    $deletedItem =  $xml.SelectNodes("/Meta/DeletedItems").DeletedItem | 
                    Where-Object -Property "#text" -eq "$Path"

    return $deletedItem
}

function Assert-MetaDeletedItem($Meta, $Path) {
    [xml]$xml = Get-Content -Path $Meta

    $deletedItem =  $xml.SelectNodes("/Meta/DeletedItems").DeletedItem | 
                    Where-Object -Property "#text" -eq "$Path"

    if ($null -ne $deletedItem) {
        return $true
    }
    return $false
}

function Add-DeletedItemToMeta($Meta, $TimeDeleted, $Path) {
    if ((Get-Date).GetType().Name -ne "DateTime") {
        Write-Log -Level "ERROR" "$TimeDeleted is not a valid DateTime object"
        Wait-Logging
        throw [System.ArgumentException]::New("$TimeDeleted is not a valid DateTime object")
    }
    if (-not (Test-Path -Path $Path)) {
        Write-Log -Level "ERROR" "$Path is not a valid path"
        Wait-Logging
        throw [System.ArgumentException]::New("$Path is not a valid path")
    }

    [xml]$xml = Get-Content -Path $Meta -ErrorAction Stop

    if (-not (Assert-MetaDeletedItem $Meta $Path)) {
        $deletedItems = $xml.SelectSingleNode("/Meta/DeletedItems")

        $newDeleted = $xml.CreateNode("element", "DeletedItem", $null)
        $newDeleted.SetAttribute("TimeDeleted", $TimeDeleted)
        $newDeleted.InnerText = $Path
        
        [void]$deletedItems.AppendChild($newDeleted)
        $xml.Save($Meta)
    }
    else {
        Write-Log -Level WARNING "$Path already exists in $Meta"
        Wait-Logging
    }
}

function Remove-DeletedItemFromMeta($Meta, $Path) {
    [xml]$xml = Get-Content -Path $Meta -ErrorAction Stop

    $deletedItem = Search-MetaDeletedItem $Meta $Path
    if ($null -ne $deletedItem) {
        #TODO: Fix this so that the element is actually removed from the document
        $xml.SelectSingleNode("/Meta/DeletedItems").RemoveChild($deletedItem)
        $xml.Save($Meta)
    }
    else {
        Write-Log -Level ERROR "$Path does not exist in $Meta"
        Wait-Logging
    }
}

Remove-DeletedItemFromMeta $meta ".\target\"