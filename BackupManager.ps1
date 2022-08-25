<#
.SYNOPSIS
    Synopsis here.
.DESCRIPTION
    Description here.
.PARAMETER Test
    asdf
.PARAMETER LogToFile
    sdfd
.EXAMPLE
    format_tags_xml.ps1 file.txt -Output out.xml -Tabs 2
    Outputs tag names as nested Tag elements in XML syntax to 'out.xml' with 2 leading tabs
.NOTES
    Author: Jeffrey Knutsen
    Date:   July 29, 2022    
#>

#TODO figure out logging/stdoutput redirection

Param(
    [Parameter(  
        HelpMessage="a"
    )]
    [switch]$Test,
    
    [Parameter(
        HelpMessage="a"
    )]
    [switch]$LogToFile
)

[xml]$config = Get-Content .\config.xml

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
        
        $backupDir = Get-ChildItem $targetBackup
        $targetDir = Get-ChildItem $target
        $files_exist_diff = Compare-Object $backupDir $targetDir -Property Name
        foreach ($diff in $files_exist_diff) {
            if ($diff.SideIndicator -eq "<=") {
                # Delete files from backup that were deleted in target
            }
            elseif ($diff.SideIndicator -eq "=>") {
                # copy files that were added in target
            }
        }

        # Update modified files
    }
    $backupCount++
}

Write-Output "Backups completed. $backupCount directories backed-up"

#Compare-Object (Get-ChildItem ".\backups\main") (Get-ChildItem ".\main\") -Property Name, LastWriteTime