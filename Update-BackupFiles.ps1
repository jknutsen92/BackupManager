Import-Module ".\BackupMeta.psm1" -Force

function Update-BackupFiles($TargetDirectory, $TargetName, $BackupDirectory, $Config, $Meta) {
    $deletedItems = (Get-DeletedItemsFromMeta $Meta).ItemName
    #TODO: Figure out why deleted items are not excluded
    $backupItems = Get-ChildItem $BackupDirectory -Recurse -Exclude $deletedItems
    if ($null -eq $backupItems) { $backupItems = "" }
    $targetItems = Get-ChildItem $TargetDirectory -Recurse
    $filesExistDiff = Compare-Object `
                -ReferenceObject $backupItems `
                -DifferenceObject $targetItems `
                -Property Name | Where-Object -Property Name -ne $null

    foreach ($diff in $filesExistDiff) {
        if ($diff.SideIndicator -eq "<=") {
            # For files that were deleted in target, flag their backups for deletion in meta file
            $destPath = (Get-ChildItem $BackupDirectory -Filter $diff.Name -Recurse).FullName
            $relativePath = (Select-String -Pattern "$TargetName\\(.+)$" -InputObject $destPath).Matches.Groups[1].Value
            $targetPath = "$TargetDirectory\$relativePath"
            Add-DeletedItemToMeta $Meta (Get-Date) $destPath $targetPath
        }
        elseif ($diff.SideIndicator -eq "=>") {
            # Copy files that were added in target
            $srcPath =  (Get-ChildItem $TargetDirectory -Filter $diff.Name -Recurse).FullName
            $srcRelativePath = (Select-String -Pattern "$TargetName\\(.+)$" -InputObject $srcPath).Matches.Groups[1].Value
            $destPath = "$BackupDirectory\$srcRelativePath"
            Copy-Item -Path $srcPath -Destination $destPath
            Write-Log -Level DEBUG "Copied new file in target $srcPath to backup at $destPath"
        }
    }
    # Copy files to backup that have been updated since previous backup
    $targetFiles = Get-ChildItem -Path $TargetDirectory -Recurse -File
    foreach ($targetFile in $targetFiles) {
        $srcPath = $targetFile.FullName
        $srcRelativePath = (Select-String -Pattern "$TargetName\\(.+)$" -InputObject $srcPath).Matches.Groups[1].Value
        $destPath = "$BackupDirectory\$srcRelativePath"
        $targetMT = (Get-Item -Path $srcPath).LastWriteTime
        $backupMT = (Get-Item -Path $destPath).LastWriteTime
        if ($targetMT -gt $backupMT) {
            Write-Log -Level DEBUG "Copying file $srcPath modified at $targetMT to $destPath, previously copied at $backupMT"
            Copy-Item -Path $srcPath -Destination $destPath
        }
    }
}