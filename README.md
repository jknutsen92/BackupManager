# BackupManager

Implements a lightweight backup solution that copies the contents of selected directories to a desired backup root folder, particularly on an external drive.

## Dependencies
Requires a minimum of Powershell 7.0 and the [Logging module](https://logging.readthedocs.io/en/latest/).

## Set Backup Directory
In the **config.xml** file, edit the _BackupRootDirectory_ tag to contain the path to the desired backup location. Each backed up directory will be copied here.

## Set Backup Targets
In the **config.xml** file, add a  _TargetDirectory_ child tag to the _TargetDirectories_ tag and insert the path to the desired directory. This directory will be backed up to the backup root directory.

## Logging
In the **config.xml** file, the _Level_ tag controls how verbose the logging messages will be. _MaxLogFiles_ will control how many log files are permitted to exist at a time, the oldest will be deleted first. _Directory_ sets the path where the log files will be saved.