# Snapshot Tool
The Snapshots Tool is a Qlik Sense Enterprise command line tool (script) that utilizes PostGreSQL and file copy commands to store backups into a folder logic the snapshots and makes it possible to jump in time between multiple snapshots. Snapshots also incorporates a "safety net" so that reversion back to previous state is possible. The tool must run from the CentralNode and will automatically identify the environment and create snaps of the current Qlik Sense environment. Another nice function is that snapshots (in shared persistent mode) can moved between environments and crucial database settings will be changed to fit the new environment.

> Snapshots tool is open source and not supported by Qlik.

### Getting started
Copy the Snapshots file into an empty folder the snapshots will be generated in the Snaps subfolder. Execute Snapshots an almost empty window will appear, this means that there are no available snapshots as you have not created any yet. Press enter and your database/App state will be copied into a backup folder including latest date and time (2018-02-07_07-27_backup), this process is usually really quick (depending on app size), no services will be stopped during the backup process. There is also a logs created containing info and error.

  - Right click on Snapshots Tool and Run as Administrator. Please validate the settings identified by Snapshots as seen in the picture below. If running Shared Persistence the App folder should be the same as application share. Root certificate is also automatically identified and presented (in this example CN=CN1-CA).
> ![N|Solid](https://raw.githubusercontent.com/QlikDeploymentFramework/Snapshots/master/Images/1.png)
- Press Enter to create a new snapshot.
> ![N|Solid](https://raw.githubusercontent.com/QlikDeploymentFramework/Snapshots/master/Images/2.png)
- After the tool has run once Snapshots will present earlier snapshots.
> ![N|Solid](https://raw.githubusercontent.com/QlikDeploymentFramework/Snapshots/master/Images/3.png)
- Add/remove/change applications or QMC settings, take more snaps and so on... 
### Recover using snaps
During recovery all Qlik Sense services except postgres need to be shutdown, in a single server setup the snapshots tool will do this automatically. In a multi node environment services on aditional nodes need to be shutdown manually
- To recover to a previous state tab to the snap (date and time) and press enter, afterwards accept selecting Y.
> ![N|Solid](https://raw.githubusercontent.com/QlikDeploymentFramework/Snapshots/master/Images/4.png)
- Recovery to the same system will work without any more questions asked.
- If recovery to another system (copying the snap between environments) an aditional selection will pop-up (after the security backup). 
> ![N|Solid](https://raw.githubusercontent.com/QlikDeploymentFramework/Snapshots/master/Images/5.png)
- Here you can select to recover using the environmental settings (Y), this is the default and usually what you want to do. Meaning that the database will be updated with the settings from the current environment/server. Pressing (N) will use the settings stored within the snapshot, that have been identified as different to the current environment.
- If Snapshots cannot find target application folder the recovery will cancel. Example, if selecting snapshot settings (N) and the apps folder is wrong the backup will stop before anything damaged.
