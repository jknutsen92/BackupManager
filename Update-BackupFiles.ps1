function Update-BackupFiles($TargetDirectory, $TargetName, $BackupDirectory, $SENTINEL_FILE) {
    $filesExistDiff = Compare-Object `
            -ReferenceObject (Get-ChildItem $BackupDirectory -Recurse -Exclude "*$SENTINEL_FILE") `
            -DifferenceObject (Get-ChildItem $TargetDirectory -Recurse -Exclude "*.$SENTINEL_FILE") `
            -Property Name

    foreach ($diff in $filesExistDiff) {
        if ($diff.SideIndicator -eq "<=") {
            # Delete files from backup that were deleted in target
            #TODO: Add a sentinel file and only delete after the delete period, and issue a warning
            $destPath = (Get-ChildItem $BackupDirectory -Filter $diff.Name -Recurse).FullName
            Remove-Item -Path $destPath
            Write-Log -Level DEBUG "Deleted file in backup $destPath that was deleted in the target"
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