Import-Module ".\BackupMeta.psm1" -Force

function Update-BackupFiles($TargetDirectory, $TargetName, $BackupDirectory, $Config, $Meta) {
    $deletedItems = (Get-DeletedItemsFromMeta $Meta).PathInBackup
    $filesExistDiff = Compare-Object `
            -ReferenceObject (Get-ChildItem $BackupDirectory -Recurse -Exclude $deletedItems) `
            -DifferenceObject (Get-ChildItem $TargetDirectory -Recurse) `
            -Property Name

    foreach ($diff in $filesExistDiff) {
        if ($diff.SideIndicator -eq "<=") {
            # For files that were deleted in target, flag their backups for deletion in meta file
            $destPath = (Get-ChildItem $BackupDirectory -Filter $diff.Name -Recurse).FullName
            Add-DeletedItemToMeta $Meta (Get-Date) $destPath
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
    $srcFiles = Get-ChildItem $TargetDirectory -Recurse
    foreach ($srcFile in $srcFiles) {
        $srcPath = $srcFile.FullName
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