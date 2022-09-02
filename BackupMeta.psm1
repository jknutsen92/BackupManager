#TODO: Handle TargetPath vs BackupPath in meta files
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

function Search-XmlDeletedItem($Xml, $PathInBackup) {
    if ($Xml.GetType().Name -ne "XmlDocument") {
        Write-Log -Level ERROR "$Xml is not a valid XML document"
        throw [System.ArgumentException]::New("$Xml is not a valid XML document")
    }
    $deletedItem =  $Xml.SelectNodes("/Meta/DeletedItems").DeletedItem | 
                    Where-Object -Property "#text" -eq "$PathInBackup"

    return $deletedItem
}

function Assert-MetaDeletedItem($Meta, $PathInBackup) {
    [xml]$xml = Get-Content -Path $Meta

    $deletedItem =  $xml.SelectNodes("/Meta/DeletedItems").DeletedItem | 
                    Where-Object -Property "#text" -eq "$PathInBackup"

    if ($null -ne $deletedItem) {
        return $true
    }
    return $false
}

function Add-DeletedItemToMeta($Meta, $TimeDeleted, $PathInBackup, $PathInTarget) {
    if ((Get-Date).GetType().Name -ne "DateTime") {
        Write-Log -Level "ERROR" "$TimeDeleted is not a valid DateTime object"
        Wait-Logging
        throw [System.ArgumentException]::New("$TimeDeleted is not a valid DateTime object")
    }
    if (-not (Test-Path -Path $PathInBackup)) {
        Write-Log -Level "ERROR" "$PathInBackup is not a valid backup path"
        Wait-Logging
        throw [System.ArgumentException]::New("$PathInBackup is not a valid backup path")
    }
    if (-not (Test-Path -Path $PathInTarget)) {
        Write-Log -Level "ERROR" "$PathInTarget is not a valid path"
        Wait-Logging
        throw [System.ArgumentException]::New("$PathInTarget is not a valid path")
    }
    if ($PathInBackup -eq $PathInTarget) {
        Write-Log -Level "ERROR" "The target path and backup path cannot be the same"
        Wait-Logging
        throw [System.ArgumentException]::New("The target path and backup path cannot be the same")
    }

    if (-not (Assert-MetaDeletedItem $Meta $PathInBackup)) {
        [xml]$xml = Get-Content -Path $Meta -ErrorAction Stop
        $deletedItems = $xml.SelectSingleNode("/Meta/DeletedItems")

        $newDeleted = $xml.CreateNode("element", "DeletedItem", $null)
        $newDeleted.SetAttribute("TimeDeleted", $TimeDeleted)
        $newDeleted.SetAttribute("PathInTarget", $PathInTarget)
        $newDeleted.InnerText = $PathInBackup
        
        [void]$deletedItems.AppendChild($newDeleted)
        $xml.Save($Meta)
    }
    else {
        Write-Log -Level WARNING "$PathInBackup already exists in $Meta"
        Wait-Logging
    }
}

function Remove-DeletedItemFromMeta($Meta, $PathInBackup) {
    [xml]$xml = Get-Content -Path $Meta -ErrorAction Stop

    $deletedItem = Search-XmlDeletedItem $xml $PathInBackup
    if ($null -ne $deletedItem) {
        [void]$xml.Meta.DeletedItems.RemoveChild($deletedItem)
        $xml.Save($Meta)
    }
    else {
        Write-Log -Level ERROR "$PathInBackup does not exist in $Meta"
        Wait-Logging
    }
}

function Get-DeletedItemsFromMeta($Meta) {
    [xml]$xml = Get-Content -Path $Meta -ErrorAction Stop
    $deletedItems = $xml.Meta.DeletedItems.DeletedItem

    $arr = [System.Collections.ArrayList]@()
    foreach($deletedItem in $deletedItems) {
        $arr += [pscustomobject]@{
            "PathInBackup"=$deletedItem."#text";
            "PathInTarget"=$deletedItem.PathInTarget;
            "TimeDeleted"=$deletedItem.TimeDeleted
        }
    }
    return $arr
}