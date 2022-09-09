Import-Module ".\BackupMeta.psm1" -Force

function Update-BackupFiles($TargetDirectory, $BackupDirectory, $Meta, $Config) {
    $targetExists = Test-Path -Path $TargetDirectory
    $metaExists = Test-Path -Path $Meta
    $targetName = (Select-String -Pattern ".+\\([^\\]+)\\?$" -InputObject $TargetDirectory).Matches.Groups[1].Value
    if (-not $metaExists) {
        if (-not $targetExists) {
            Write-Log -Level ERROR "'$TargetDirectory' does not exist and there is no corresponding meta file"
            Wait-Logging
            return
        }
        else {
            Write-Log -Level ERROR "Meta file does not exist in '$Meta'. Regenerating"
            New-Meta $Meta $targetName $TargetDirectory
        }
    }

    [xml]$xmlDocument = Get-Content $Meta
    $dirElementName = Get-ValidXmlDirectoryName $targetName
    $directoryElement = $xmlDocument.Meta.DirectoryTree.$dirElementName

    $value = [int]$Config.Config.FileRetention.DeleteBackupAfterTargetDeleted."#text"
    $unit = $Config.Config.FileRetention.DeleteBackupAfterTargetDeleted.unit
    switch ($unit) {
        "Days" { $deletePeriod = New-TimeSpan -Days $value }
    }
    Write-Log -Level INFO "All deleted files and directories in the target will be deleted in the backup after $value $unit"

    if ($targetExists) {
        # Target directory is valid, update child directories
        Compare-Directories $TargetDirectory $BackupDirectory $xmlDocument $directoryElement $deletePeriod
    }
    elseif ([Boolean]$xmlDocument.Meta.TargetDeleted) {
        # Target directory was deleted since last backup
        $expirationDT = [DateTime]$xmlDocument.Meta.TimeDeleted + $deletePeriod
        Write-Log -Level WARNING "'$TargetDirectory' will expire and be deleted on $expirationDT "
    }
    else {
        # Target directory was newly deleted since last backup
        Write-Log -Level WARNING "'$TargetDirectory' was deleted. The backup will be deleted after $value $unit"
        $xmlDocument.Meta.SetAttribute("TargetDeleted", "True")
        $xmlDocument.Meta.SetAttribute("TimeDeleted", (Get-Date).ToString())
    }
    $xmlDocument.Save($Meta)
    Wait-Logging
}

function Compare-Directories($TargetDirectory, $BackupDirectory, $XmlDocument, $DirectoryElement, $DeletePeriod) {
    Write-Log -Level DEBUG "`r`n`r`nComparing target directory '$TargetDirectory' to backup directory '$backupDirectory'"
    $deletedItems = Get-DeletedItems $DirectoryElement
    Write-Log -Level DEBUG "$($deletedItems.Count) deleted items in '$TargetDirectory' since last backup - [$($deletedItems.Name)]"

    $directoriesInTarget =  Get-ChildItem -Path $TargetDirectory -Directory
    $filesInTarget =        Get-ChildItem -Path $TargetDirectory -File
    $directoriesInBackup =  Get-ChildItem -Path $BackupDirectory -Directory -Exclude $deletedItems.Name

    $directoriesChanged =   Compare-Object  -ReferenceObject    ($directoriesInTarget.Name ?? '') `
                                            -DifferenceObject   ($directoriesInBackup.Name ?? '') |
                                            Where-Object -Property InputObject -ne ''

    # Update directories
    foreach ($directoryChanged in $directoriesChanged) {
        if ($directoryChanged.SideIndicator -eq "<=") {
            # In target but not in backup
            if ($deletedItems.Name?.Contains($directoryChanged.InputObject)) {
                # Deleted directory in target was restored after last backup
                Remove-DeletedItem $DirectoryElement $directoryChanged.InputObject
                Write-Log -Level INFO "Directory '$($directoryChanged.InputObject)' was restored in '$TargetDirectory' since last backup. Restoring in '$BackupDirectory'"
            }
            else {
                # New directory
                New-Item -Path "$BackupDirectory\$($directoryChanged.InputObject)" -ItemType Directory | Out-Null
                Add-DirectoryToMeta $XmlDocument $DirectoryElement $directoryChanged.InputObject
                Write-Log -Level INFO "New directory '$($directoryChanged.InputObject)' added to '$TargetDirectory'. Adding to $BackupDirectory"
            }
        }
        elseif ($directoryChanged.SideIndicator -eq "=>") {
            # In backup, but target was deleted
            Add-DeletedItem $XmlDocument $DirectoryElement $directoryChanged.InputObject
            Write-Log -Level WARNING "Directory '$($directoryChanged.InputObject)' was deleted in '$TargetDirectory'"
        }
    }

    # Check target directory for new or updated files
    foreach ($file in $filesInTarget) {
        Write-Log -Level DEBUG "Checking file '$($file.Name)' in '$TargetDirectory'"
        if (-not (Test-Path -Path "$BackupDirectory\$($file.Name)")) {
            # New file in target does not yet exist in backup
            Copy-Item -Path $file.FullName -Destination "$BackupDirectory\$($file.Name)"
            Write-Log -Level INFO "New file '$($file.Name)' in '$TargetDirectory'. Copied to '$BackupDirectory'"
        }
        elseif ($file.LastWriteTime -gt (Get-Item -Path "$BackupDirectory\$($file.Name)").LastWriteTime) {
            # File in target has been updated since last backup
            Copy-Item -Path $file.FullName -Destination "$BackupDirectory\$($file.Name)"
            Write-Log -Level INFO "File '$($file.Name)' in '$TargetDirectory' was updated since last backup. Copying new version to '$BackupDirectory\$($file.Name)'"
        }
    }

    $filesInBackup =        Get-ChildItem   -Path $BackupDirectory -File      -Exclude $deletedItems.Name
    $fileDiffs =            Compare-Object  -ReferenceObject    ($filesInTarget.Name ?? '') `
                                            -DifferenceObject   ($filesInBackup.Name ?? '') |
                                            Where-Object -Property InputObject -ne ''

    # Check for newly deleted or restored files in the target directory
    foreach ($fileDiff in $fileDiffs) {
        if ($fileDiff.SideIndicator -eq "=>") {
            # File deleted in target
            Add-DeletedItem $XmlDocument $DirectoryElement $fileDiff.InputObject
            Write-Log -Level WARNING "File '$($fileDiff.InputObject)' was deleted in '$TargetDirectory'"
        }
        elseif ($fileDiff.SideIndicator -eq "<=" -and $deletedItems.Name?.Contains($fileDiff.InputObject)) {
            # Deleted file in target was restored
            Remove-DeletedItem $DirectoryElement $fileDiff.InputObject
            Write-Log -Level INFO "File '$($fileDiff.InputObject)' was restored in '$TargetDirectory'. Restoring in '$BackupDirectory'"
        }
    }

    # Delete any expired files/directories in backup
    $nowDT = Get-Date
    foreach ($deletedItem in $deletedItems) {
        $expirationDT = [DateTime]$deletedItem.TimeDeleted + $DeletePeriod
        $deletedPath = "$BackupDirectory\$($deletedItem.Name)"
        if ($nowDT -ge $expirationDT) {
            # File has expired since last backup
            if ((Get-Item -Path $deletedPath).PSIsContainer) {
                # Item is a directory
                Remove-Item -Path $deletedPath -Recurse
                Remove-DirectoryFromMeta $DirectoryElement $deletedItem.Name
                Write-Log -Level INFO "Directory '$deletedPath' has expired and has been deleted"
            }
            else {
                # Item is a file
                Remove-Item -Path $deletedPath
                Write-Log -Level INFO "File '$deletedPath' has expired and has been deleted"
            }
            Remove-DeletedItem $DirectoryElement $deletedItem.Name
        }
        else {
            # File has not yet expired
            Write-Log -Level WARNING "'$deletedPath' has been deleted from '$TargetDirectory' and will expire and be deleted after $expirationDT"
        }
    }

    # Check subdirectories
    foreach ($childDirectory in $directoriesInTarget) {
        $childElement = Get-ChildDirectoryElement $DirectoryElement $childDirectory.Name
        $childTarget = "$TargetDirectory\$($childDirectory.Name)"
        $childBackup = "$BackupDirectory\$($childDirectory.Name)"
        Compare-Directories $childTarget $childBackup $XmlDocument $childElement $DeletePeriod
    }
}