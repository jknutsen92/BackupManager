# BackupManager

Implements a lightweight backup solution that copies the contents of selected directories to a desired backup root folder, particularly on an external drive.

**Set Backup Directory**
In the **config.xml** file, edit the **BackupRootDirectory** tag to contain the path to the desired backup location. Each backed up directory will be copied here.

**Set Backup Targets**
In the **config.xml** file, add a  **TargetDirectory** child tag to the **TargetDirectories** tag and insert the path to the desired directory. This directory will be backed up to the backup root directory.

**Logging**
In the **config.xml** file, the **Level** tag controls how verbose the logging messages will be. **MaxLogFiles** will control how many log files are permitted to exist at a time, the oldest will be deleted first. **Directory** sets the path where the log files will be saved.
