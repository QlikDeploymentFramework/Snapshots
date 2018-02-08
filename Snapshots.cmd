@echo off
::-------- Settings section starts ---------------------------------
SET Version=2.2
::--- Local Sense Data folder, usually %ProgramData%\Qlik
SET SenseDataFolder=%ProgramData%\Qlik

::--- PostgreSQL settings

SET PostgreHome=%ProgramFiles%\Qlik\Sense\Repository\PostgreSQL

::--- Auto identify postgres version
for /f %%i in ('dir "%PostgreHome%\9.*" /B') do set PostGreVersion=%%i
::--- Manual set postgres version
:: SET PostGreVersion=9.6

SET PostgreBin=%PostgreHome%\%PostGreVersion%\bin
SET PostgreConf=%SenseDataFolder%\Sense\Repository\PostgreSQL\%PostGreVersion%
SET PostgreLocation=localhost
SET PostgreAccount=postgres
SET PostGrePort=4432
SET PostGreDB=QSR

::--- PGPASSWORD add password, also consider creating a %APPDATA%\postgresql\pgpass.conf file
::SET PGPASSWORD=<password>

::--- Exported Certificate Password
SET CertExportPWD=QlikSense

::--- Activate to backup ArchivedLogs, else no logs will be backed
::SET BackupArchivedLogs=true

::--- Default folder settings, settings below are identifyed automatically when running Shared Persistence
::--- Warning! Modify only if using Multi Sync, else folders are identified automatically
SET Apps=%SenseDataFolder%\Sense\Apps
SET StaticContent=%SenseDataFolder%\Sense\Repository
SET CustomData=%SenseDataFolder%\Custom Data
SET ArchivedLogs=%SenseDataFolder%\Archived Logs 

::-------- Settings section end ------------------------------------------
::------------------------------------------------------------------------

:: Sub to set date and time
SET Section=createfolders &goto isodate

:createfolders
::--- Home and backup locations default is same folder as script
mkdir "%~dp0\Snaps"
SET backupdir=%2
SET Home=%~dp0\Snaps
SET SettingsFolder=%~dp0\Settings
SET LogFolder=%~dp0\Log
mkdir "%SettingsFolder%"
mkdir "%LogFolder%"
SET LogFile=%LogFolder%\%_isodate%

:: Set PostGreSQL password if not using a %APPDATA%\postgresql\pgpass.conf file
if NOT EXIST "%APPDATA%\postgresql\pgpass.conf" SET Section=GetCertInfo &goto Setpwd

:GetCertInfo
::--- Auto identify Qlik Sense CA certificate, remark to use hardcoded cert names
for /f %%i in ('powershell.exe -nologo -noprofile -command "$store = Get-Item \"cert:\LocalMachine\Root\"; $store.Open(\"ReadOnly\"); $certs = $store.Certificates.Find(\"FindByExtension\", \"1.3.6.1.5.5.7.13.3\", $false);$certs.Thumbprint"') do set RootCertName=%%i
for /f %%i in ('powershell.exe -nologo -noprofile -command "$store = Get-Item \"cert:\LocalMachine\Root\"; $store.Open(\"ReadOnly\"); $certs = $store.Certificates.Find(\"FindByExtension\", \"1.3.6.1.5.5.7.13.3\", $false);$certs.Subject"') do set RootSubjectName=%%i

::--- Auto identify Qlik Sense Personal certificate, remark to use hardcoded cert names 
for /f %%i in ('powershell.exe -nologo -noprofile -command "$store = Get-Item \"cert:\LocalMachine\My\"; $store.Open(\"ReadOnly\"); $certs = $store.Certificates.Find(\"FindByExtension\", \"1.3.6.1.5.5.7.13.3\", $false);$certs.Thumbprint"') do set Certificate=%%i
::--- Auto identify Qlik Sense Client certificate, remark to use hardcoded cert names 
for /f %%i in ('powershell.exe -nologo -noprofile -command "$store = Get-Item \"cert:\CurrentUser\My\"; $store.Open(\"ReadOnly\"); $certs = $store.Certificates.Find(\"FindByExtension\", \"1.3.6.1.5.5.7.13.3\", $false);$certs.Thumbprint"') do set ClientCert=%%i

::--- Auto identify Shared Persistance folder settings by quering PostGreSQL
pushd "%PostgreBin%"

for /f %%i in ('psql -qtA -h %PostgreLocation% -p %PostGrePort% -U %PostgreAccount% -d %PostGreDB% -c "SELECT \"HostName\" FROM \"LocalConfigs\" ; "') do set HostName=%%i
IF "%HostName%"=="" echo Could not access PostgreSQL DB:%PostGreDB% Server:%PostgreLocation% Port:%PostGrePort% Account:%PostgreAccount%  &echo %_isodate% Could not access PostgreSQL DB:%PostGreDB% Server:%PostgreLocation% Port:%PostGrePort% Account:%PostgreAccount% , exit Snapshots>>"%LogFile%_Error.log" & exit

for /f "delims="  %%i in ('psql -qtA -h %PostgreLocation% -p %PostGrePort% -U %PostgreAccount% -d %PostGreDB% -c "SELECT \"AppFolder\" FROM \"ServiceClusterSettingsSharedPersistenceProperties\" ; "') do set SP_Active=%%i

if "%SP_Active%"==""  goto Skip_SP
SET Apps=%SP_Active%
for /f "delims=" %%i in ('psql -qtA -h %PostgreLocation% -p %PostGrePort% -U %PostgreAccount% -d %PostGreDB% -c "SELECT \"StaticContentRootFolder\" FROM \"ServiceClusterSettingsSharedPersistenceProperties\" ; "') do set StaticContent=%%i
for /f "delims=" %%i in ('psql -qtA -h %PostgreLocation% -p %PostGrePort% -U %PostgreAccount% -d %PostGreDB% -c "SELECT \"Connector64RootFolder\" FROM \"ServiceClusterSettingsSharedPersistenceProperties\" ; "') do set CustomData=%%i
for /f "delims=" %%i in ('psql -qtA -h %PostgreLocation% -p %PostGrePort% -U %PostgreAccount% -d %PostGreDB% -c "SELECT \"RootFolder\" FROM \"ServiceClusterSettingsSharedPersistenceProperties\" ; "') do set RootFolder=%%i
for /f "delims=" %%i in ('psql -qtA -h %PostgreLocation% -p %PostGrePort% -U %PostgreAccount% -d %PostGreDB% -c "SELECT \"DatabaseHost\" FROM \"ServiceClusterSettingsSharedPersistenceProperties\" ; "') do set DatabaseHost=%%i
for /f "delims=" %%i in ('psql -qtA -h %PostgreLocation% -p %PostGrePort% -U %PostgreAccount% -d %PostGreDB% -c "SELECT \"ArchivedLogsRootFolder\" FROM \"ServiceClusterSettingsSharedPersistenceProperties\" ; "') do set ArchivedLogs=%%i

::psql -qtA -h %PostgreLocation% -p %PostGrePort% -U %PostgreAccount% -d %PostGreDB% -c "SELECT \"StaticContentRootFolder\" FROM \"ServiceClusterSettingsSharedPersistenceProperties\" >> "%Home%\Settings.cmd"

:skip_SP
popd


if "%2"=="" SET backupdir=%_isodate%_%computername%

CD "%Home%"

if "%1"=="silent" goto Backup

pushd "%SettingsFolder%"
::echo #### Settings.cmd MD5 hash added 
for /f %%i in ('powershell.exe -nologo -noprofile -command "Get-FileHash -Path Settings.cmd -Algorithm MD5| Select-Object -ExpandProperty Hash"') do set HashBaseline=%%i
::echo #### HashBaseline= %HashBaseline%

if "%1"=="restore" goto Backup_end

:: Go to Common settings file sub
SET Section=DIR &goto SettingsFile

:DIR
popd

cls
echo ---- Snapshots v%Version% identified config:  -------
echo PostGreSQL Name: %PostgreLocation%
echo App folder: %Apps%
echo RootCert Subject Name: %RootSubjectName%
::echo Server Hostname found in DB: %HostName%

echo.
echo -------  Available Snapshots:  --------
echo.
dir "%Home%\*" /B /A:D 
echo.


echo Type name or tab snapshot to recover db
echo To create a Sense backup just hit enter
echo.
echo ______________________________________
echo.
SET /P DBFolder=
echo.


IF NOT EXIST "%Home%\%DBFolder%\*.*" goto DIR
if "%DBFolder%"=="" goto Backup

Choice /M " Do you want to recover snap %DBFolder%, press Y to continue"
echo.
IF ERRORLEVEL 2 goto DIR


::echo #### Dissable %PostGreDB%

::psql -qtA -h %PostgreLocation% -p %PostGrePort% -U %PostgreAccount% -d %PostGreDB% -c "ALTER DATABASE \"%PostGreDB%\" SET default_transaction_read_only = true;"

::echo #### Terminate all connections from %PostGreDB%
::psql -qtA -h %PostgreLocation% -p %PostGrePort% -U %PostgreAccount% -d %PostGreDB% -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '%PostGreDB%' AND pid <> pg_backend_pid();"

:: Sub to set date and time
SET Section=Backup &goto isodate

:Backup

cls

if NOT "%2"== "" SET backupdir=%2& echo #### Starting Backup, identified backup folder %backupdir% &echo %_isodate% Starting Backup, identified backup folder %backupdir% >>"%LogFile%_Info.log"

If "%DBFolder%"=="" goto Backup_all
IF "%DBFolder%"=="%backupdir%" goto dropdb

:Backup_all
IF NOT EXIST "%Apps%"* echo #### Could not find any apps under %Apps%  &echo %_isodate% Could not find any apps under %Apps%, exit backup >>"%LogFile%_Error.log" & goto Backup_end
SET Section=Backup_all

echo #### Backup content &echo %_isodate% Backup content from: "%Apps%" "%StaticContent%" "%CustomData%">>"%LogFile%_Info.log" 
robocopy "%Apps%" "%Home%\%backupdir%\Apps" /mir  /NP /NJH /NJS /R:10 /w:3
robocopy "%StaticContent%" "%Home%\%backupdir%\StaticContent" /XD "Exported Certificates" "Archived Logs" "PostgreSQL" "TempContent" "Transaction Logs" "DefaultExtensionTemplates" "DefaultApps" /E /NP /NJH /NJS /R:3 /w:1
if "%BackupArchivedLogs%"=="true" robocopy "%ArchivedLogs%" "%Home%\%backupdir%\ArchivedLogs" /mir  /NP /NJH /NJS /R:3 /w:1
robocopy "%CustomData%" "%Home%\%backupdir%\CustomData"  /XF *.Log /E /NP /NJH /NJS /R:3 /w:1

:: Sub to set date and time
SET Section=BackupDB &goto isodate
:BackupDB

echo #### Backing up %PostGreDB% database
echo #### Copy database to "%Home%\%backupdir%\%PostGreDB%_backup.tar" &echo %_isodate% Copy database to "%Home%\%backupdir%\%PostGreDB%_backup.tar">>"%LogFile%_Info.log"
pushd "%PostgreBin%"
pg_dump.exe -h %PostgreLocation% -p %PostGrePort% -U %PostgreAccount%  -o -b -F t -f "%Home%\%backupdir%\%PostGreDB%_backup.tar" %PostGreDB%

echo #### Copy PostGre configuration files
robocopy "%PostgreConf%" "%Home%\%backupdir%\PostGreConf" *.conf /NP /NJH /NJS /R:10 /w:3

echo #### Copy Host.cfg configuration files
robocopy "%SenseDataFolder%\Sense" "%Home%\%backupdir%" Host.cfg /NP /NJH /NJS /R:10 /w:3

echo #### Copy Exported Certificates
robocopy "%SenseDataFolder%\Sense\Repository\Exported Certificates" "%Home%\%backupdir%\ExportedCertificates" /S /NP /NJH /NJS /R:10 /w:3

echo.
echo #### Backup identified certificates &echo %_isodate% Backup identified certificates: %RootCertName% %Certificate% %ClientCert%>>"%LogFile%_Info.log"

certutil  -f  -p %CertExportPWD% -exportpfx -privatekey Root %RootCertName% "%Home%\%backupdir%\root.pfx" 
certutil  -f  -p %CertExportPWD% -exportpfx  MY %Certificate% "%Home%\%backupdir%\server.pfx" NoRoot
certutil  -f  -p %CertExportPWD% -exportpfx -user MY %ClientCert% "%Home%\%backupdir%\client.pfx" NoRoot

echo #### Backup complete, snap stored under %Home%\%backupdir% &echo %_isodate% Backup complete, snap stored under %Home%\%backupdir%>>"%LogFile%_Info.log" 

popd

echo #### Store settings file into snap
pushd "%Home%\%backupdir%\"

SET Section=Backup_end
:: Go to Common settings file sub
goto SettingsFile

:Backup_end
if "%1"=="silent" goto end

if NOT "%2"== "" SET DBFolder=%2& echo #### identified recovery folder "%DBFolder%"

if "%DBFolder%"=="" goto end

if NOT exist "%Home%\%DBFolder%\" echo #### Can't find "%DBFolder%" &echo %_isodate% Can't find "%DBFolder%" , exit recovery>>"%LogFile%_Error.log" &goto end

:: Sub to set date and time
SET Section=dropdb &goto isodate
:dropdb

pushd "%Home%\%DBFolder%\"

echo #### Starting recovery of snapshot %DBFolder%, MD5 hash created &echo %_isodate% Starting recovery of snapshot %DBFolder%, MD5 hash created >>"%LogFile%_Info.log"
for /f %%i in ('powershell.exe -nologo -noprofile -command "Get-FileHash -Path Settings.cmd -Algorithm MD5| Select-Object -ExpandProperty Hash"') do set BackupHash=%%i
::echo #### BackupHash= %BackupHash%
::echo #### HashBaseline= %HashBaseline%
if %BackupHash% == %HashBaseline% goto Stop_Services
cls
echo ---------------------------------------------------------------
echo .
echo #### There is a diff between destination environment and the selected snapshot &echo %_isodate% There is a diff between destination environment and the selected snapshot %DBFolder%>>"%LogFile%_Info.log"
echo #### Snapshots will continue after 10 sec using destination settings &echo %_isodate% Snapshots will continue after 10 sec using destination settings>>"%LogFile%_Info.log"
Choice /T 10 /D Y /M "Press N to use snaps settings and Y for default environmental"
IF NOT ERRORLEVEL 2 goto Stop_Services
echo #### changing snapshot settings
SET SettingsFolder=%Home%\%DBFolder%

:Stop_Services
popd

call "%SettingsFolder%\Settings.cmd"

IF NOT EXIST "%Apps%" echo #### Recovery canceled! can't find destination app folder %Apps% &echo %_isodate% Recovery canceled! can't find destination app folder %Apps% >>"%LogFile%_Error.log"   &goto end

pushd "%PostgreBin%"

echo.
echo #### Restore %PostGreDB% database
echo.


echo #### Stop Services on %computername% &echo %_isodate% Stop Services on %computername% >>"%LogFile%_Info.log"
NET stop "QlikSenseEngineService" /Yes
NET stop "QlikSenseProxyService" /Yes
NET stop "QlikSenseSchedulerService" /Yes
net stop "QlikSensePrintingService" /Yes
NET stop "QlikSenseRepositoryService" /Yes
NET stop "QlikSenseServiceDispatcher" /Yes

Taskkill /im Engine.exe /f

::echo #### Set %PostGreDB% write access
::psql -qtA -h %PostgreLocation% -p %PostGrePort% -U %PostgreAccount% -d %PostGreDB% -c "begin; set transaction read write; alter database \"%PostGreDB%\" set default_transaction_read_only = off; commit;"
::psql -qtA -h %PostgreLocation% -p %PostGrePort% -U %PostgreAccount% -d %PostGreDB% -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '%PostGreDB%' AND pid <> pg_backend_pid();">NULL

 :: Sub to set date and time
SET Section=createdb &goto isodate
:createdb

echo #### Drop %PostGreDB% &echo %_isodate% Terminate connections and drop %PostGreDB% >>"%LogFile%_Info.log"
psql -qtA -h %PostgreLocation% -p %PostGrePort% -U %PostgreAccount% -d %PostGreDB% -c "begin;ALTER DATABASE \"%PostGreDB%\" SET default_transaction_read_only = true;commit;"
psql -qtA -h %PostgreLocation% -p %PostGrePort% -U %PostgreAccount% -d %PostGreDB% -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '%PostGreDB%' AND pid <> pg_backend_pid();">>"%LogFile%_Info.log"
dropdb -h %PostgreLocation% -p %PostGrePort% -U %PostgreAccount% %PostGreDB%
IF NOT %ERRORLEVEL%==0 echo ### Could not drop database will exit & echo %_isodate% Could not drop database, exit recovery>>"%LogFile%_Error.log"  &goto end


echo #### Create %PostGreDB% &echo %_isodate% createdb -h %PostgreLocation% -p %PostGrePort% -U %PostgreAccount% -T template0 %PostGreDB% >>"%LogFile%_Info.log"

createdb -h %PostgreLocation% -p %PostGrePort% -U %PostgreAccount% -T template0 %PostGreDB%
IF NOT %ERRORLEVEL%==0 goto %Section%

:: Sub to set date and time
SET Section=pg_restore &goto isodate
:pg_restore

echo.
echo #### Restore %PostGreDB% &echo %_isodate% pg_restore.exe -h %PostgreLocation% -p %PostGrePort% -U %PostgreAccount% -d %PostGreDB% "%Home%\%DBFolder%\%PostGreDB%_backup.tar" >>"%LogFile%_Info.log"


pg_restore.exe -h %PostgreLocation% -p %PostGrePort% -U %PostgreAccount% -d %PostGreDB% "%Home%\%DBFolder%\%PostGreDB%_backup.tar"


::echo #### %PostGreDB% read only during recovery
::psql -qtA -h %PostgreLocation% -p %PostGrePort% -U %PostgreAccount% -d %PostGreDB% -c "ALTER DATABASE \"%PostGreDB%\" SET default_transaction_read_only = true;"

:: Sub to set date and time
SET Section=RestoreContent &goto isodate
:RestoreContent

echo #### Replace content &echo %_isodate% Replace content: "%Apps%" "%StaticContent%" "%CustomData%">>"%LogFile%_Info.log"

robocopy "%Home%\%DBFolder%\Apps" "%Apps%" /mir  /NP /NJH /NJS /R:10 /w:3
robocopy "%Home%\%DBFolder%\StaticContent" "%StaticContent%" /S /NP /NJH /NJS /R:10 /w:3
if "%BackupArchivedLogs%"=="true" robocopy "%Home%\%DBFolder%\ArchivedLogs" "%ArchivedLogs%" /S /NP /NJH /NJS /R:3 /w:1
robocopy "%Home%\%DBFolder%\CustomData" "%CustomData%"  /S /NP /NJH /NJS /R:10 /w:3


echo #### Set %PostGreDB% write access
psql -qtA -h %PostgreLocation% -p %PostGrePort% -U %PostgreAccount% -d %PostGreDB% -c "begin; set transaction read write; alter database \"%PostGreDB%\" set default_transaction_read_only = off; commit;"
if "%SP_Active%"==""  goto Start_Services

echo #### Call settings and adjusting database values

psql -qtA -h %PostgreLocation% -p %PostGrePort% -U %PostgreAccount% -d %PostGreDB% -c "begin;Update \"ServiceClusterSettingsSharedPersistenceProperties\" SET \"AppFolder\" ='%Apps%'; commit;"
psql -qtA -h %PostgreLocation% -p %PostGrePort% -U %PostgreAccount% -d %PostGreDB% -c "begin;Update \"ServiceClusterSettingsSharedPersistenceProperties\" SET \"StaticContentRootFolder\" ='%StaticContent%'; commit;"
psql -qtA -h %PostgreLocation% -p %PostGrePort% -U %PostgreAccount% -d %PostGreDB% -c "begin;Update \"ServiceClusterSettingsSharedPersistenceProperties\" SET \"Connector64RootFolder\" ='%CustomData%'; commit;"
psql -qtA -h %PostgreLocation% -p %PostGrePort% -U %PostgreAccount% -d %PostGreDB% -c "begin;Update \"ServiceClusterSettingsSharedPersistenceProperties\" SET \"Connector32RootFolder\" ='%CustomData%'; commit;"
psql -qtA -h %PostgreLocation% -p %PostGrePort% -U %PostgreAccount% -d %PostGreDB% -c "begin;Update \"ServiceClusterSettingsSharedPersistenceProperties\" SET \"RootFolder\" ='%RootFolder%'; commit;"
psql -qtA -h %PostgreLocation% -p %PostGrePort% -U %PostgreAccount% -d %PostGreDB% -c "begin;Update \"ServiceClusterSettingsSharedPersistenceProperties\" SET \"ArchivedLogsRootFolder\" ='%ArchivedLogs%'; commit;"
::psql -qtA -h %PostgreLocation% -p %PostGrePort% -U %PostgreAccount% -d %PostGreDB% -c "begin;Update \"LocalConfigs\" SET \"HostName\" ='%HostName%'; commit;"

SET Section=Start_Services &goto isodate
:Start_Services 
echo.
echo #### Start services on %computername% &echo %_isodate% Start services on %computername% >>"%LogFile%_Info.log"

NET start "QlikSenseRepositoryService"
NET start "QlikSenseEngineService"
NET start "QlikSenseProxyService"
NET start "QlikSenseSchedulerService"
net start "QlikSensePrintingService"
NET start "QlikSenseServiceDispatcher"

echo #### Recovery complete &echo %_isodate% Recovery complete >>"%LogFile%_Info.log"
:end

::echo #### Terminate all connections from %PostGreDB%
::psql -qtA -h %PostgreLocation% -p %PostGrePort% -U %PostgreAccount% -d %PostGreDB% -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '%PostGreDB%' AND pid <> pg_backend_pid();"

popd
echo #### Snapshots done
exit

:: Sub for creating settins file
:SettingsFile
echo #### Creating recovery settings file
echo SET Apps=%Apps%>"Settings.cmd"
echo SET StaticContent=%StaticContent%>> "Settings.cmd"
echo SET CustomData=%CustomData%>> "Settings.cmd"
echo SET ArchivedLogs=%ArchivedLogs%>> "Settings.cmd"
echo SET RootFolder=%RootFolder%>> "Settings.cmd"
::echo SET HostName=%HostName%>> "Settings.cmd"
::echo SET DatabaseHost=%DatabaseHost%>> "Settings.cmd"

popd
goto %Section%

:isodate
:: Sub to identifiyng date and time
FOR /F "skip=1 tokens=1-6" %%G IN ('WMIC Path Win32_LocalTime Get Day^,Hour^,Minute^,Month^,Second^,Year /Format:table') DO (
   IF "%%~L"=="" goto s_done
      Set _yyyy=%%L
      Set _mm=00%%J
      Set _dd=00%%G
      Set _hour=00%%H
      SET _minute=00%%I
)
:s_done

:: Pad digits with leading zeros
      Set _mm=%_mm:~-2%
      Set _dd=%_dd:~-2%
      Set _hour=%_hour:~-2%
      Set _minute=%_minute:~-2%

:: Display the date/time in ISO 8601 format:
Set _isodate=%_yyyy%-%_mm%-%_dd%_%_hour%-%_minute%
goto %Section%

:Setpwd
::### Hidden PostgreSQL password input (if not added in settings section)
cls
if "%PGPASSWORD%"=="" set "psCommand=powershell -Command "$pword = read-host 'Enter password for user %PostgreAccount%' -AsSecureString ; ^
    $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pword); ^
        [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)""
if "%PGPASSWORD%"=="" for /f "usebackq delims=" %%p in (`%psCommand%`) do set PGPASSWORD=%%p

goto %Section%