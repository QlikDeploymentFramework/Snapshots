# Snapshot Tool
The Snapshots Tool is a Qlik Sense Enterprise command line tool (script) that utilizes PostGreSQL and file copy commands to store backups into a folder logic the snapshots and makes it possible to jump in time between multiple snapshots. Snapshots also incorporates a "safety net" so that reversion back to previous state is possible. The tool must run from the CentralNode and will automatically identify the environment and create snaps of the current Qlik Sense environment.

> Snapshots tool is open source and not supported by Qlik.

### Prerequisites
- Snapshots need Powershell 4.0 or later to be installed on the server.
- Snapshots need to run on the CentralNode to backup certificates from *Windows certificate store*
- Snapshots should run under the same service account as Qlik Repository Service to backup client certificates (not critical, there are other certificate backups that can be used instead)
- In an active/passive configuration, moving snapshots between the environments. Both environments must to use the same certificates.

### Getting started
Your current Qlik Sense database and App state (among others) are copied into a backup folder (snapshot) named with date and time (*2018-02-07_07-27_backup*). Taking a snapshot goes usually quite swift (depending apps and size), and no services need to stop during the backup process. Info and error logs are created during both backup and recovery.
 
  1. Copy *Snapshots.cmd* into an empty folder (snapshots and logs are generated in subfolder) 
  2. Right click on Snapshots Tool and Run as Administrator.
  3. Add PostgreSQL password, default account name is *postgres*
  4. Validate settings identified by Snapshots (seen below). If running Shared Persistence the App folder should be the same as application share. Root certificate is identified and presented (in this example CN=CN1-CA). First time start there are no available snapshots (as you have not created any yet).
```sh  
----- Snapshots 2.2 identified config:  ------
PostGreSQL Name: localhost
App folder: \\CentralNode\QlikShare
RootCert Subject Name: CN=CN1-CA
```
 5. Press Enter to create a new snapshot.
 ```sh
 -------  Available Snapshots:  --------
 
Type name or tab snapshot to recover db
To create a Sense backup just hit enter
_______________________________________
|
 ```
 6. As soon as Snapshots tool has run earlier snapshots are presented.
  ```sh
-------  Available Snapshots:  --------
2018-02-07_07-27_backup

Type name or tab snapshot to recover db
To create a Sense backup just hit enter
______________________________________
|
 ```
 7. You can now add/remove/change Qlik Sense applications settings, take more snaps and so on... 
### Recover using snaps
During recovery all Qlik Sense services except postgres need to be shutdown, in a single server setup the snapshots tool will do this automatically. 
> In a multi node environment services on aditional nodes need to be shutdown manually
 1. To recover to a previous state tab to the snapshot and press enter, afterwards accept selecting Y.
   ```sh
Type name or tab snapshot to recover db
To create a Sense backup just hit enter
______________________________________
2018-02-07_07-27_backup
Do you want to recover snap 2018-02-07_07-27_backup, press Y to continue [Y/N]?
 ```
 2. Recovery to the same system will work without any more questions asked.
 3. If recovering on another environment (copying the snap between environments) an aditional question will show.
```sh
There is a diff between destination environment and the selected snapshot
Snapshots will continue after 10 sec using destination settings
Press N to use snapshots settings or Y for default environmental [Y/N]?
 ```
 4. Here you have the choice of recovering using the current server settings (Y), meaning that the backup settings are replaced with the current environment/server setting. This is the default and usually what you want to do. Pressing (N) will keep the original snapshot settings. As Snapshots should execute silently there is a 10sec window to press (N) else (Y) is automaticaly set
 5. If Snapshots cannot find target application folder the recovery will exit. Example, if selecting snapshot settings (N) and the apps folder is wrong the backup will stop before anything is damaged.

## Switches
### Silent snapshots
- You can also create snapshots silently without command-line interaction, using the **silent** switch. Using this to schedule the snapshots (example Windows scheduler).
```sh
snapshots.cmd silent
```
- **Silent** does not work together without a pre-set PostGreSQL password. Access will be validated, if denied Snapshots will exit. Please uncomment *set PGPASSWORD=<PassWord>* and add the pwd. You can also store pwd in *%APPDATA%\postgresql\pgpass.conf* file. Read more under settings section.

### Silent snapshot with fixed name
- **Silent** switch can also be extended with a fixed **backup_name** (instead of default date/time/server), in this way it becomes easier to create recovery scripts as the snapshot name is known.
```sh
snapshots.cmd silent backup_name
```
### Silent restore
- The switch **restore backup_name** can be use for active/passive clusters where you want to transfer a snap from the active site and recover on the passive site in time intervals. For this to work we need to use above silent snapshot with fixed name during the backup as well.
```sh
snapshots.cmd restore backup_name
```
## Settings
Below is the available Snapshots settings, usually the defaults will work as Snaps identifies certificates and content folders automatically.
```sh
@echo off
::-------- Settings section starts ---------------------------------
set Version=2.2
::--- Local Sense Data folder, usually %ProgramData%\Qlik
set SenseDataFolder=%ProgramData%\Qlik
::--- PostgreSQL settings
set PostgreHome=%ProgramFiles%\Qlik\Sense\Repository\PostgreSQL
::--- Auto identify postgres version
for /f %%i in ('dir "%PostgreHome%\9.*" /B') do set PostGreVersion=%%i
::--- Manual set postgres version
:: set PostGreVersion=9.6
set PostgreBin=%PostgreHome%\%PostGreVersion%\bin
set PostgreConf=%SenseDataFolder%\Sense\Repository\PostgreSQL\%PostGreVersion%
set PostgreLocation=localhost
set PostgreAccount=postgres
set PostGrePort=4432
set PostGreDB=QSR
::--- PGPASSWORD add password, also consider creating a %APPDATA%\postgresql\pgpass.conf file
::set PGPASSWORD=<PassWord>
::--- Exported Certificate Password
set CertExportPWD=QlikSense
::--- Activate to backup ArchivedLogs, else no logs will be backed
::set BackupArchivedLogs=true
```
### Certificate Export Password
To change the default certificate export password modify: 
```sh
set CertExportPWD=QlikSense
```
## PostgreSQL settings
There are several PostgreSQL settings most usually do not need to be changed, below are the most important.

### PostgreSQL location (SET PostgreLocation)
Change *PostgreLocation* if the database is located on remote system.
```sh
set PostgreLocation=localhost 
```
### PostgreSQL account name
Change the setting below to change default accont name 
```sh
set PostgreAccount=postgres
```
### PostgreSQL password
If no password set Snapshots will ask for Postgre password during startup, for silent backup and recovery you need to set a fixed password.
Uncomment PGPASSWORD in the script and replace <PassWord> with the actual password. 
```sh
set PGPASSWORD=<Password>
```
Postgres access will be validated, if access is denied Snapshots will terminate writing an error log.
You can also add the file *%APPDATA%\postgresql\pgpass.conf* to store credentials for the account running the script, read more here. Postgres access will be validated, if access is denied Snapshots will terminate writing an error log. pgpass.conf file must have format: 
```sh
%APPDATA%\postgresql\pgpass.conf 
hostname:port:database:username:password
Example: localhost:4432:QSR:postgres:Qlik1234
```
### PostgreSQL Home
The Postgre program folder, usually *%ProgramFiles%\Qlik\Sense\Repository\PostgreSQL* 
```sh
set PostgreHome
``` 
Snapshots will automatically identify the PostgreSQL version, this can manually set
```sh
set PostGreVersion=9.6
``` 
## Log
Log files is created for every backup and recovery, stored under Log folder created by snapshots:
>  ![N|Solid](https://raw.githubusercontent.com/QlikDeploymentFramework/Snapshots/master/Images/9.png)
#### There are two kinds of log files:
- **Error log** contains errors breaking backup or recovery, like a database lock that can't be removed or the database can't be accessed as seen below.
```sh
2017-05-30_04-01 Could not access PostgreSQL DB:QSR Server:localhost Port:4432 Account:postgres
```
-  **Info log** contains progress information, as seen below.
```sh 2017-05-30_05-57 Backup content from: "\\CENTRALNODE\QlikShare\Apps" "\\CENTRALNODE\QlikShare\StaticContent" "\\CENTRALNODE\QlikShare\CustomData" 
2017-05-30_05-57 Copy database to "C:\Snapshots Tool\Snaps\2017-05-30_05-56_CENTRALNODE\QSR_backup.tar"
```
