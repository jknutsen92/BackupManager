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

#TODO: Address removing .sentinel file when the target file is found again in the source
#TODO: Cleanup excessive nesting in logic

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

if ($LogToFile) {
    #Requires -Module Logging

    $logDir = $config.Config.Logging.Directory
    $logLevel = $config.Config.Logging.Level
    [int]$maxLogs = $config.Config.Logging.MaxLogFiles

    $nLogs = (Get-ChildItem $logDir | Measure-Object).Count
    if ($nLogs -ge $maxLogs) {
        $oldestWriteTime = (
                        Get-ChildItem $logDir | 
                        Select-Object -Property LastWriteTime | 
                        Measure-Object -Property LastWriteTime -Minimum | 
                        Select-Object -Property Minimum
        ).Minimum
        $oldestLogFile =Get-ChildItem $logDir | 
                        Where-Object -Property LastWriteTime -eq $oldestWriteTime

        Remove-Item $oldestLogFile
    }
    $dtStr = Get-Date -Format "MM-dd-yyyy@HH-mm-ss"
    $logName = "Backup-Directories_Log_$dtStr.log"

    Set-LoggingDefaultLevel -Level $logLevel
    Add-LoggingTarget -Name Console
    Add-LoggingTarget -Name File -Configuration @{
        Path="$logDir\$logName"
    }
}

if ($Test) {
    Write-Log -Level DEBUG "Running in test mode"
    $targetDirectories = $config.Config.Test.TargetDirectories.TargetDirectory
    $backupRootDirectory = $config.Config.Test.BackupRootDirectory
}
else {
    Write-Log -Level DEBUG "Running in production mode"
    $targetDirectories = $config.Config.TargetDirectories.TargetDirectory
    $backupRootDirectory = $config.Config.BackupRootDirectory
}

$timer = [Diagnostics.Stopwatch]::StartNew()

$backupCount = 0
foreach ($target in $targetDirectories) {
    Write-Log -Level DEBUG "Accessing target directory $target"
    $targetRegex = Select-String -Pattern ".+\\([^\\]+)\\?$" -InputObject $target
    $targetName = $targetRegex.Matches.Groups[1].Value
    $targetBackup = "$backupRootDirectory\$targetName"
    $targetBackupExists = Test-Path -Path $targetBackup

    if (-not (Test-Path -Path $target) -and (-not $targetBackupExists)) {
        Write-Log -Level ERROR "$target does not exist and there is no corresponding backup"
        continue
    }

    if (-not $targetBackupExists) {
        Write-Log -Level DEBUG "$targetName does not exist in backup directory."
        Copy-Item -Path $target -Destination $targetBackup -Recurse
        Write-Log -Level INFO "Copied $target to $targetBackup"
        continue
    }

    $targetDir = Get-ChildItem $target -Recurse -Exclude "*$SENTINEL_FILE" -ErrorAction Ignore
    if ($null -ne $targetDir) {
        $backupCount++
        $filesExistDiff = Compare-Object `
            -ReferenceObject (Get-ChildItem $targetBackup -Recurse -Exclude "*$SENTINEL_FILE") `
            -DifferenceObject $targetDir -Property Name

        foreach ($diff in $filesExistDiff) {
            if ($diff.SideIndicator -eq "<=") {
                # Delete files from backup that were deleted in target
                #TODO: Add a sentinel file and only delete after the delete period, and issue a warning
                $destPath = (Get-ChildItem $targetBackup -Filter $diff.Name -Recurse).FullName
                Remove-Item -Path $destPath
                Write-Log -Level DEBUG "Deleted file in backup $destPath that was deleted in the target"
            }
            elseif ($diff.SideIndicator -eq "=>") {
                # Copy files that were added in target
                $srcPath =  (Get-ChildItem $target -Filter $diff.Name -Recurse).FullName
                $srcRelativePath = (Select-String -Pattern "$targetName\\(.+)$" -InputObject $srcPath).Matches.Groups[1].Value
                $destPath = "$targetBackup\$srcRelativePath"
                Copy-Item -Path $srcPath -Destination $destPath
                Write-Log -Level DEBUG "Copied new file in target $srcPath to backup at $destPath"
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
                Write-Log -Level DEBUG "Copying file $srcPath modified at $targetMT to $destPath, previously copied at $backupMT"
                Copy-Item -Path $srcPath -Destination $destPath
            }
        }
    }
    else {
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
                Write-Log -Level INFO "Deleted backup $target after staling for $value $units"
            }
            else {
                Write-Log -Level WARNING "$targetBackup will be deleted on $deleteTime"
            }
        }
        else {
            Write-Log -Level INFO "Target directory $target was emptied or deleted"
            New-Item -Path "$targetBackup\$SENTINEL_FILE" -ItemType File
            Write-Log -Level WARNING "$targetBackup will be deleted from backup after $value $units"
        }
    }
}
$timer.Stop()
$seconds = $timer.Elapsed.TotalSeconds
Write-Log -Level INFO "Backups completed in $seconds seconds. $backupCount directories backed-up"
Wait-Logging