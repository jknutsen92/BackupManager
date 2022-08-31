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

#TODO: Replace sentinel files with an XML file for each backup directory that lists the deleted files

#Requires -Module Logging

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

Import-Module ".\Update-BackupFiles.ps1"    -Force
Import-Module ".\Sync-DeletedDirectory.ps1" -Force
Import-Module ".\BackupMeta.psm1"           -Force

$META_DIR = ".\meta\"

# Config settings
[xml]$config = Get-Content .\config.xml

Add-LoggingTarget -Name Console
Set-LoggingDefaultLevel -Level $config.Config.Logging.Level
if ($LogToFile) {
    $logDir = $config.Config.Logging.Directory
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
    $targetName = (Select-String -Pattern ".+\\([^\\]+)\\?$" -InputObject $target).Matches.Groups[1].Value
    $backup = "$backupRootDirectory\$targetName"
    $backupExists = Test-Path -Path $backup
    $metaPath = "$META_DIR\$targetName.xml"

    if (-not (Test-Path -Path $target) -and (-not $backupExists)) {
        Write-Log -Level ERROR "$target does not exist and there is no corresponding backup"
    }
    elseif (-not $backupExists) {
        Write-Log -Level DEBUG "$targetName does not exist in backup directory."
        Copy-Item -Path $target -Destination $backup -Recurse
        Write-Log -Level INFO "Copied $target to $backup"

        New-Meta $metaPath $targetName
        Write-Log -Level DEBUG "Meta file $targetName.xml created"
    }
    elseif ($null -ne (Get-ChildItem $target -Recurse -ErrorAction Ignore)) {
        $backupCount++
        Update-BackupFiles $target $targetName $backup $config $meta
    }
    else {
        Sync-DeletedDirectory $target $backup $config $meta
    }
    # Process DeletedItems in meta file
    Confirm-DeletedItems $metaPath
}
$timer.Stop()
$seconds = $timer.Elapsed.TotalSeconds
Write-Log -Level INFO "Backups completed in $seconds seconds. $backupCount directories backed-up"
Wait-Logging