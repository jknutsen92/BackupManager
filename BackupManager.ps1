<#
.SYNOPSIS
    Backs up directories listed in the 'config.xml' file.
.DESCRIPTION
    Backs up directories listed in the 'config.xml' file. Will also delete files in the backup that were deleted
    in the target directories after a period of time specified in 'config.xml.'
.PARAMETER Test
    Runs the script in test mode. The script will use the corresponding test settings in 'config.xml.'
.PARAMETER LogToFile
    The script will write log output to a file, specified in 'config.xml,' instead of the console.
.EXAMPLE
    .\BackupManager.ps1 -Test
    Runs the BackupManager script in test mode with all output written to the console.
.EXAMPLE
    .\BackupManager.ps1 -LogToFile
    Runs the BackupManager script in production mode and writes all output to a log file.
.NOTES
    Author: Jeffrey Knutsen
    Date:   August 25, 2022    
#>

#TODO figure out logging/stdoutput redirection

Param(
    [Parameter(  
        HelpMessage="Executes the script in testing mode"
    )]
    [switch]$Test,
    
    [Parameter(
        HelpMessage="Writes all logging output to log files specified in 'config.xml'"
    )]
    [switch]$LogToFile
)
# Constants
$SENTINEL_FILE =  ".sentinel"

# Config settings
[xml]$config = Get-Content .\config.xml

function Backup-Directories($Test, $config, $SENTINEL_FILE) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    if ($Test) {
        Write-Verbose "Running in test mode"
        $targetDirectories = $config.Config.Test.TargetDirectories.TargetDirectory
        $backupRootDirectory = $config.Config.Test.BackupRootDirectory
    }
    else {
        Write-Verbose "Running in production mode"
        $targetDirectories = $config.Config.TargetDirectories.TargetDirectory
        $backupRootDirectory = $config.Config.BackupRootDirectory
    }

    $backupCount = 0
    foreach ($target in $targetDirectories) {
        Write-Verbose "Accessing target directory $target"
        $targetRegex = Select-String -Pattern ".+\\([^\\]+)\\?$" -InputObject $target
        $targetName = $targetRegex.Matches.Groups[1].Value
        $targetBackup = "$backupRootDirectory\$targetName"
        $targetBackupExists = Test-Path -Path $targetBackup

        if (-not $targetBackupExists) {
            Write-Verbose "$targetName does not exist in backup directory."
            Copy-Item -Path $target -Destination $targetBackup -Recurse
            Write-Output "Copied $target to $targetBackup"
        }
        else {
            $targetDir = Get-ChildItem $target -Recurse -Exclude "*$SENTINEL_FILE" -ErrorAction Ignore
            if ($null -ne $targetDir) {
                $backupCount++
                $filesExistDiff = Compare-Object `
                    -ReferenceObject (Get-ChildItem $targetBackup -Recurse -Exclude "*$SENTINEL_FILE") `
                    -DifferenceObject $targetDir -Property Name
            }
            else {
                Write-Output "Target directory $target was emptied or deleted"
                $units = $config.Config.FileRetention.DeleteBackupAfterTargetDeleted.unit
                $value = $config.Config.FileRetention.DeleteBackupAfterTargetDeleted."#text"

                if (Test-Path -Path "$targetBackup\$SENTINEL_FILE") {
                    $sentienlMT = (Get-Item -Path "$targetBackup\$SENTINEL_FILE").LastWriteTime
                    switch ($units) {
                        "Days" { $deletePeriod = New-TimeSpan -Days $value }
                    }
                    $now = Get-Date
                    $deleteTime = $sentienlMT + $deletePeriod
                    if ($now -ge $deleteTime) {
                        Remove-Item -Path $targetBackup -Recurse
                        Write-Output "Deleted backup $target after staling for $value $units"
                    }
                    else {
                        Write-Warning "$targetBackup will be deleted on $deleteTime"
                    }
                }
                else {
                    New-Item -Path "$targetBackup\$SENTINEL_FILE" -ItemType File
                    Write-Warning "$targetBackup will be deleted from backup after $value $units"
                }
            }

            foreach ($diff in $filesExistDiff) {
                if ($diff.SideIndicator -eq "<=") {
                    # Delete files from backup that were deleted in target
                    #TODO: Add a sentinel file and only delete after the delete period, and issue a warning
                    $destPath = (Get-ChildItem $targetBackup -Filter $diff.Name -Recurse).FullName
                    Remove-Item -Path $destPath
                    Write-Verbose "Deleted file in backup $destPath that was deleted in the target"
                }
                elseif ($diff.SideIndicator -eq "=>") {
                    # Copy files that were added in target
                    $srcPath =  (Get-ChildItem $target -Filter $diff.Name -Recurse).FullName
                    $srcRelativePath = (Select-String -Pattern "$targetName\\(.+)$" -InputObject $srcPath).Matches.Groups[1].Value
                    $destPath = "$targetBackup\$srcRelativePath"
                    Copy-Item -Path $srcPath -Destination $destPath
                    Write-Verbose "Copied new file in target $srcPath to backup at $destPath"
                }
            }
            # Copy files to backup that have been updated since previous backup
            $srcFiles = Get-ChildItem $target -Recurse
            foreach ($srcFile in $srcFiles) {
                $srcPath = $srcFile.FullName
                $srcRelativePath = (Select-String -Pattern "$targetName\\(.+)$" -InputObject $srcPath).Matches.Groups[1].Value
                $destPath = "$targetBackup\$srcRelativePath"
                $targetMT = (Get-Item -Path $srcPath).LastWriteTime
                $backupMT = (Get-Item -Path $destPath).LastWriteTime
                if ($targetMT -gt $backupMT) {
                    Write-Verbose "Copying file $srcPath modified at $targetMT to $destPath, previously copied at $backupMT"
                    Copy-Item -Path $srcPath -Destination $destPath
                }
            }
        }
    }
    $timer.Stop()
    $seconds = $timer.Elapsed.TotalSeconds
    Write-Output "Backups completed in $seconds seconds. $backupCount directories backed-up"
}

if ($LogToFile) {
    #TODO: Implement logging to file
}
else {
    Backup-Directories $Test $config $SENTINEL_FILE
}