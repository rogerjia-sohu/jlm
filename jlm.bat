
>nul 2>&1
@cls
@echo off && goto _BATCH_MAIN
******************************************************************************************
    JCS License Manager
    Copyright (C) 2011- Jedat China Software Inc. All rights reserved.
    syntax :
        JLM [{/B | /L | /U [servicename] | /R}] [/F licensefile] [/D]
    History: 2011/02 (1st release)
             2011/03/01 + Added parameter /F licensefile
             2011/04/14 + Added another two ways to get mac in case of one's failure
             2011/04/27 * Set license environment to system wide instead of current user
     Autor : AE Team@JCS
     Note  : For Jedat License Only (Daemon must be jedat)
******************************************************************************************

:_BATCH_MAIN
rem BEGIN MAIN
setlocal enabledelayedexpansion
set BAT_DEBUG=0
set Ver.Major=1
set Ver.Minor=0
for /f "tokens=1-3 delims=/- " %%x in ("%~t0") do set Ver.Rev=Rev.%%x-%%y-%%z
set TRACE=rem
echo %0 | find """">nul && set Me.Mode=GUI|| set Me.Mode=CLI&& rem %
set Me.PathOnly=%~dps0&& set Me.PathName=%~dpfs0

call :_jlmInit0
set L_ALL_CMDLINE=%*&& rem %
if defined L_ALL_CMDLINE set L_ALL_CMDLINE=%L_ALL_CMDLINE:/?=-?%
call :_jlmParseCmdLine %L_ALL_CMDLINE%&& rem %
call :_jlmInit
if %Me.ErrNum% geq 1 call :_jlmShowErrInfo && goto _END
if defined Me.GetHelp call :_jlmUsage && goto _END

if %L_FUNC% leq %L_JLM_INSTALL_REDUNDANT% (
	call %Me.PathName% /L>nul && (call %Me.PathName% /U | find /v /i %Ver.Info% && %CRLF%)
	call :_jlmInstall %L_FUNC% && set FirewallOp=0 1
) else if %L_FUNC% equ %L_JLM_LIST% (
	call :_jlmListSvc %1&& rem %
) else if %L_FUNC% equ %L_JLM_UNINSTALL% (
	call :_jlmUninstallSvc %UserServiceName% && set FirewallOp=0
)
if %Me.ErrNum% geq 1 call :_jlmShowErrInfo && goto _END
if defined FirewallOp (
	echo Configuring Windows Firewall ...
	for /f "tokens=1-2" %%a in ("%FirewallOp%") do (
		call :_jlmConfigMSWinFirewall %%a
		call :_jlmConfigMSWinFirewall %%b
	)
	echo Finished.
)
goto _END
rem END MAIN

rem ---- BEGIN SUB_ROUTINES ----
:_jlmParseCmdLine
%TRACE0% %~0&& rem %
rem Description of %L_FUNC%
rem     0, install/update on a single server (default)
rem     1, install/update on one of the redundant servers (specify /R)
rem     2, list services (specify /L)
rem     3, uninstall service (specify /U [servicename])
set L_FUNC=0
set L_BACKUP_LIC=0
if %Me.ErrNum% geq 1 exit /b %Me.ErrNum%
:__nextparam
if "%~1"=="" exit /b 0
set param1="%~1"
if "%param1:~1,1%"=="/" set param1=%param1:/=-%

if /i %param1%=="-H" (
	set Me.GetHelp=1&& exit /b 0
) else if /i %param1%=="-HELP" (
	set Me.GetHelp=1&& exit /b 0
) else if %param1%=="-?" (
	set Me.GetHelp=1&& exit /b 0
) else if /i %param1%=="-B" (
	set L_BACKUP_LIC=1
) else if /i %param1%=="-D" (
	set BAT_DEBUG=1
) else if /i %param1%=="-R" (
	set L_FUNC=1
) else if /i %param1%=="-L" (
	set L_FUNC=2
) else if /i %param1%=="-U" (
	set L_FUNC=3
	set param2="%~2"&& rem %
	set detectsvcname=0
	%TRACE% param2=!param2!
	if !param2!=="" (
		set detectsvcname=1
	) else (
		if !param2!=="-?" set Me.GetHelp=1&& exit /b 0
		set param2=!param2:/=-!
		if /i !param2!=="-H" set Me.GetHelp=1&& exit /b 0
		if /i !param2!=="-HELP" set Me.GetHelp=1&& exit /b 0
		if "!param2:~1,1!"=="-" set detectsvcname=1
		if /i !param2!=="-D" set BAT_DEBUG=1
	)
	%TRACE% detectsvcname=!detectsvcname!
	if !detectsvcname! geq 1 (
		call %Me.PathName% /L>nul && (
			for /f "tokens=1,2 delims=:	" %%m in ('%Me.PathName% /l') do if /i "%%m"=="Service Name" set UserServiceName=%%n
		) || (
			set Me.ErrNum=%L_JLM_ERR_NO_SERVICE%
			set Me.ErrParam=%1&& rem %
			exit /b %Me.ErrNum%
		)
	) else (
		set UserServiceName=!param2!
	)
	%TRACE% UserServiceName=%UserServiceName%
	shift /1
) else if /i %param1%=="-F" (
	set param2="%~2"&& rem %
	if !param2!=="" (
		set missingparam=1
	) else (
		if !param2!=="-?" set Me.GetHelp=1&& exit /b 0
		set param2=!param2:/=-!
		if /i !param2!=="-H" set Me.GetHelp=1&& exit /b 0
		if /i !param2!=="-HELP" set Me.GetHelp=1&& exit /b 0
		if "!param2:~1,1!"=="-" set missingparam=1
		if /i !param2!=="-D" set BAT_DEBUG=1
	)
	if "!missingparam!"=="1" (
		set Me.ErrNum=%L_JLM_ERR_NO_REQUIRED_PARAM%
		set Me.ErrParam=%1&& rem %
		%TRACE% #E%Me.ErrNum%
		exit /b %ErrNum%
	)
	set MyLicFile=%~f2&& rem %
	if exist "!MyLicFile!" (
		echo !MyLicFile!>%Me.Tempfile1%
		shift /1
	) else (
		set Me.ErrNum=%L_JLM_ERR_NO_LICFILE%
		set Me.ErrParam="!MyLicFile!"
		%TRACE% #E%Me.ErrNum%
		exit /b %ErrNum%
	)
) else (
	set Me.ErrNum=%L_JLM_ERR_UNKNOWN_PARAM%
	set Me.ErrParam=%1&& rem %
	%TRACE% #E%Me.ErrNum%
	exit /b %Me.ErrNum%
)
shift /1
goto __nextparam
exit /b 0

:_jlmInit0
set L_TAB=	&&set CRLF=echo.&&set BEEP=echo 
set Me.Title="JLM"
set Ver.Info="[Version %Ver.Major%.%Ver.Minor% %Ver.Rev%]"
echo %Me.Title:"=% %Ver.Info:"=%&& %CRLF%
set Me.ErrNum=0
set Me.ErrParam=
rem Error numbers
set L_JLM_ERR_CANT_WRITE_TEMPDIR=1
set L_JLM_ERR_CANT_WRITE_CURDIR=2
set L_JLM_ERR_NO_LICFILE=3
set L_JLM_ERR_NO_HOSTID=4
set L_JLM_ERR_NOT_JEDAT_LIC=5
set L_JLM_ERR_ID_NOT_MATCH=6
set L_JLM_ERR_SERVERS_NOT_ONLINE=7
set L_JLM_ERR_NO_SERVICE=8
set L_JLM_ERR_NO_REQUIRED_PARAM=9
set L_JLM_ERR_UNKNOWN_PARAM=10
set L_JLM_ERR_NOT_ADMIN=11&& rem ! This MUST be the maximum value !
set /a L_JLM_ERR_MAX_VAL=%L_JLM_ERR_NOT_ADMIN% + 1
rem Error messages
set L_JLM_MSG_%L_JLM_ERR_CANT_WRITE_TEMPDIR%=Cannot write to temporary directory.
set L_JLM_MSG_%L_JLM_ERR_CANT_WRITE_CURDIR%=Cannot write to current directory.
set L_JLM_MSG_%L_JLM_ERR_NO_LICFILE%=License file was not found.
set L_JLM_MSG_%L_JLM_ERR_NO_HOSTID%=Host ID was not found.
set L_JLM_MSG_%L_JLM_ERR_NOT_JEDAT_LIC%=Invalid license file.
set L_JLM_MSG_%L_JLM_ERR_ID_NOT_MATCH%=License file is incompitable with this machine.
set L_JLM_MSG_%L_JLM_ERR_SERVERS_NOT_ONLINE%=Not all servers were online as specified in file.
set L_JLM_MSG_%L_JLM_ERR_NO_SERVICE%=No installed service was found.
set L_JLM_MSG_%L_JLM_ERR_NO_REQUIRED_PARAM%=Required paramater was missing.
set L_JLM_MSG_%L_JLM_ERR_UNKNOWN_PARAM%=Unknown paramter.
set L_JLM_MSG_%L_JLM_ERR_NOT_ADMIN%=You do not have Administrator rights.
set L_JLM_MSG_%L_JLM_ERR_MAX_VAL%=Unknow error occured.
set Me.Tempfile1=%TEMP%\tmp%RANDOM%.txt
set Me.Tempfile2=%TEMP%\tmp%RANDOM%.txt
set Me.Tempfile3=%TEMP%\tmp%RANDOM%.txt
set Me.Tempfile4=%TEMP%\tmp%RANDOM%.txt
set Me.Tempvbs1=%Me.PathOnly%tmp%RANDOM%.vbs
fsutil file createnew %Me.Tempfile1% 0 >nul && (
	fsutil file createnew %Me.Tempvbs1% 0 >nul || (
		set Me.ErrNum=%L_JLM_ERR_CANT_WRITE_CURDIR%
		set Me.ErrParam=%Me.Tempvbs1%
	)
) || (
	set Me.ErrNum=%L_JLM_ERR_CANT_WRITE_TEMPDIR%
	set Me.ErrParam=%Me.Tempfile1%
)
exit /b %Me.ErrNum%

:_jlmInit
if defined BAT_DEBUG if %BAT_DEBUG% geq 1 set TRACE=echo
set TRACE0=%TRACE%&&set TRACE=%TRACE% %L_TAB%
%TRACE0% * BEGIN DEBUG:	%DATE% %TIME%
%TRACE0% %~0&& rem %
%TRACE% L_ALL_CMDLINE=%L_ALL_CMDLINE%
%TRACE% L_FUNC=%L_FUNC%
set DefSvcName="Jedat License Manager"
set DefSvcDispName="Jedat License Manager"
set DefDaemonDispName="Jedat License Daemon"
set DefLicExt=.lic
set DefLicLogExt=.log
set DefSvcBin=lmgrd.exe
set DefDaemon=jedat.exe
set JLM_VAR_NAME=JEDAT_LICENSE_FILE
for /f "tokens=*" %%h in ('hostname') do set MyHostName=%%h
set L_SC_ERR_NOT_INSTALLED=1060
set L_JLM_INSTALL_SINGLE=0
set L_JLM_INSTALL_REDUNDANT=1
set L_JLM_LIST=2
set L_JLM_UNINSTALL=3
set FirewallOp=
call :_jlmCheckAdminUser %USERNAME%
exit /b %Me.ErrNum%

:_jlmCheckAdminUser
%TRACE0% %~0 %~1&& rem _jlmCheckAdminUser username
%TRACE% net localgroup "Administrators" ^| find /i "%~1"
net localgroup "Administrators" | find /i "%~1" >nul && exit /b 0 || %TRACE% NG
set Me.ErrNum=%L_JLM_ERR_NOT_ADMIN%
set Me.ErrParam=%1&& rem %
exit /b %Me.ErrNum%

:_jlmInstall
%TRACE0% %~0&& rem %
set _func=%1&& rem %
echo Auto configuration is in progress, please wait ...
if not defined MyLicFile call :_jlmGetLicenseList
%TRACE% LicenseList:&& if exist %Me.Tempfile1% for /f "tokens=*" %%f in (%Me.Tempfile1%) do %TRACE% %L_TAB%%%f
if not exist %Me.Tempfile1% (
	set Me.ErrNum=%L_JLM_ERR_NO_LICFILE%
	set Me.ErrParam=%Me.PathOnly%
	exit /b %Me.ErrNum%
)

call :_jlmGetMyMacList
%TRACE% MyMacList:&& if exist %Me.Tempfile2% for /f "tokens=*" %%m in (%Me.Tempfile2%) do %TRACE% %L_TAB%%%m
if not exist %Me.Tempfile2% (
	set Me.ErrNum=%L_JLM_ERR_NO_HOSTID%
	set Me.ErrParam=%COMPUTERNAME%
	exit /b %Me.ErrNum%
)

if %_func% equ %L_JLM_INSTALL_REDUNDANT% goto _jlmInstallRedundant
echo Using:%L_TAB%single-server mode

call :_jlmGetMyLicInfo MyLicFile ServerLine MyMac ServerPort DaemonLine
%TRACE% MyLicFile:%L_TAB%["%MyLicFile%"]
%TRACE% ServerInfo:%L_TAB%["%ServerLine%, %MyMac%, %ServerPort%, %DaemonLine%"]

if not defined MyLicFile set Me.ErrNum=%L_JLM_ERR_ID_NOT_MATCH%
if %Me.ErrNum% geq 1 exit /b %Me.ErrNum%

for /f "tokens=*" %%s in ("%MyLicFile%") do echo Using:%L_TAB%%MyLicFile%, %%~ts&& %CRLF%
echo %MyLicFile%,%ServerLine%,SERVER %MyHostName% %MyMac% %ServerPort%,!DaemonLine!>%Me.Tempfile3%

if defined L_BACKUP_LIC if %L_BACKUP_LIC% geq 1 call :_jlmBackupFile %MyLicFile%
goto _jlmInstallCommon

:_jlmInstallRedundant
%TRACE0% %~0&& rem %
echo Using:%L_TAB%redundant-server mode&& %CRLF%
echo Checking computers in LAN ...
call :_jlmGetLanMacList
call :_jlmGetMyLanLicInfo
if not exist %Me.Tempfile3% (
	set Me.ErrNum=%L_JLM_ERR_ID_NOT_MATCH%
	set Me.ErrParam=%COMPUTERNAME%
	exit /b %Me.ErrNum%
)
set _servercnt=0
set _prevlicfile=
echo Using:
for /f "tokens=1 delims=," %%f in (%Me.Tempfile3%) do (
	set /a _servercnt=!_servercnt! + 1
	if not "!_prevlicfile!"=="%%f" echo %L_TAB%%%f%L_TAB%%%~tf
	set _prevlicfile=%%f
)
%CRLF%
if %_servercnt% lss 3 (
	set Me.ErrNum=%L_JLM_ERR_SERVERS_NOT_ONLINE%
	set Me.ErrParam=!_prevlicfile!
	exit /b %Me.ErrNum%
)
goto _jlmInstallCommon

:_jlmInstallCommon
%TRACE0% %~0&& rem %
call :_jlmUpdateLicFile
call :_jlmRegLicEnv 1
if not %errorlevel% equ 0 (
	echo #W: Cannot add user environment variable automatically
	echo Please add it manually with the following information: 
	echo   * No leading or trailing spaces *
	echo   Variable name:%L_TAB%%JLM_VAR_NAME%
	echo   Variable value:%L_TAB%%_var_value%
	%CRLF%
	start rundll32 shell32,Control_RunDLL sysdm.cpl,,3
)

call :_jlmCheckService
set SvcSts=%errorlevel%
if not %SvcSts% equ %L_SC_ERR_NOT_INSTALLED% (
	call :_jlmStopService
	call :_jlmDeleteService
)

call :_jlmCreateService
call :_jlmStartService
exit /b %errorlevel%

:_jlmUsage
%TRACE0% %~0&& rem %
echo %~n0 [{/B ^| /L ^| /U [servicename] ^| /R}] [/F licensefile] [/D]&& echo. &&rem %
echo   /B          Backup original license file while installing or updating.
echo   /L          List installed services.
echo   /U          Uninstall a service by detecting automatically.
echo   servicename Specifies a service name to be uninstalled.
echo   /R          Install on one of the redundant servers.
echo   /F          Install service using specified license file.
echo   licensefile Specifies a license file.
echo   /D          Enable debug output. (e.g.: %~n0 /D ^>%~n0.log)
echo.
echo All paramaters are case insensitive, and "/" can also be replaced with "-".
echo ("%~n0 -l" is equivalent to "%~n0 /L".)
exit /b

:_jlmShowErrInfo
%TRACE0% %~0&& rem %
if not defined Me.ErrNum exit /b 0
if %Me.ErrNum% geq %L_JLM_ERR_MAX_VAL% (
	set ErrMsgL1=#E^(%Me.ErrNum%^): !L_JLM_MSG_%L_JLM_ERR_MAX_VAL%! ^(%Me.ErrParam%^)
) else (
	set ErrMsgL1=#E^(%Me.ErrNum%^): !L_JLM_MSG_%ME.ErrNum%! ^(%Me.ErrParam%^)
)
echo %ErrMsgL1%
%BEEP%
exit /b 0

:_jlmGetLicenseList
%TRACE0% %~0&& rem %
call :_jlmInitFile %Me.Tempfile1%
for /f %%f in ('dir *%DefLicExt% /b /s /o-d 2^>nul ^| find /v /i "_bak-"') do (
	if exist %%~ff echo %%~ff>>%Me.Tempfile1%
)
if exist %Me.Tempfile1% (exit /b 0) else (exit /b 1)

:_jlmGetMyMacList
%TRACE0% %~0&& rem %
rem Use getmac directly
%TRACE% Trying getmac ...
for /f "tokens=1-6 delims=- " %%a in ('getmac ^| find /i "-"') do (
	echo %%a%%b%%c%%d%%e%%f>>%Me.Tempfile2%
)
if not exist %Me.Tempfile2% (
rem Try wmic in case of 'getmac' failed
%TRACE% Trying wmic ...
	for /f "tokens=1-6 delims=: " %%a in ('wmic nicconfig where "ipenabled=true" get macaddress ^| find ":"') do (
		echo %%a%%b%%c%%d%%e%%f>>%Me.Tempfile2%
	)
)
if not exist %Me.Tempfile2% (
rem Try ipconfig in case of wmic failed
%TRACE% Trying ipconfig ...
	start "" /min /wait cmd.exe /c "chcp 437 && for /f "tokens=3-8 delims=:.- " %%a in ('ipconfig /all ^| find /i "Physical"') do @echo %%a%%b%%c%%d%%e%%f>>%Me.Tempfile2%"
)
exit /b 0

:_jlmGetMyLicInfo
%TRACE0% %~0&& rem %
for /f "tokens=*" %%f in (%Me.Tempfile1%) do (
	set Me.ErrParam=%%f
	for /f "tokens=*" %%m in (%Me.Tempfile2%) do (
		for /f "tokens=1-5 delims=:	 " %%A in ('findstr /i /n /r "SERVER.*%%m" %%f') do (
			set %1=%%f
			set %2=%%A
			set %3=%%m
			set %4=%%E
			for /f "tokens=1 delims=:	 " %%L in ('findstr /i /n /r /c:"DAEMON *	*jedat" %%f') do (
				set %5=%%L&& exit /b 0 && rem %
			)
		)
	)
)
set Me.ErrNum=%L_JLM_ERR_NOT_JEDAT_LIC%
%TRACE% #E%Me.ErrNum%
exit /b %Me.ErrNum%

:_jlmGetMyLanLicInfo
%TRACE0% %~0&& rem %
call :_jlmInitFile %Me.Tempfile3%
for /f "tokens=*" %%f in (%Me.Tempfile1%) do (
	set daemonline=0
	for /f "tokens=1 delims=:	 " %%L in ('findstr /i /n /r "DAEMON *	*jedat" %%f') do set daemonline=%%L
	if !daemonline! geq 1 (
		set linenum=0
		for /f "tokens=1-4" %%A in (%%f) do (
			set /a linenum=!linenum! + 1
			if /i "%%A"=="SERVER" (
				for /f "tokens=1 delims=," %%N in ('findstr /i "%%C" %Me.Tempfile2%') do (
					echo %%f,!linenum!,%%A %%N %%C %%D,!daemonline!>>%Me.Tempfile3%
				)
			)
		)
	) && rem END if !daemonline!
)
exit /b 0

:_jlmBackupFile
%TRACE0% %~0&& rem %
set srcfile="%~f1"&& rem %Holds UE's highlighting
set srcfilename=%~dpn1&& rem %Holds UE's highlighting
set srcext=%~x1&& rem %Holds UE's highlighting
for /f "tokens=1-6 delims=/:." %%a in ("%date%.%time%") do (
	set bakfile="%srcfilename%_BAK-%%a%%b%%c-%%d%%e%srcext%"
)
if defined bakfile if exist %srcfile% copy %srcfile% %bakfile% /v /y >nul
set srcfile=&& set srcfilename=&& set srcext=&& set bakfile=
exit /b 0

:_jlmUpdateLicFile
%TRACE0% %~0&& rem %
if not exist %Me.Tempfile3% exit /b 1
set _licpath=%MyLicFile%
set _newlicpath=%_licpath%.new
for /f "tokens=1-4 delims=," %%A in (%Me.Tempfile3%) do (
	set _licpath=%%A
	set	_serverline=%%B
	set _serverinfo=%%C
	set _daemonline=%%D

	set _newlicpath=!_licpath!.new
	if exist !_newlicpath! del /f /q !_newlicpath!
	set cnt=0
	for /f "tokens=* delims= " %%a in (!_licpath!) do (
		set /a cnt=!cnt! + 1
		if !cnt! equ !_serverline! (
			echo !_serverinfo!>>!_newlicpath!
		) else if !cnt! equ !_daemonline! (
			echo DAEMON jedat %~dps0!DefDaemon!>>!_newlicpath! && rem %
		) else (
			echo %%a>>!_newlicpath!
		)
	)
	if exist !_newlicpath! move /y !_newlicpath! !_licpath!>nul
)
set _licpath=&& set _newlicpath=
exit /b 0

:_jlmGetLanMacList
%TRACE0% %~0&& rem %
call :_jlmInitFile %Me.Tempfile2%
for /f "tokens=1 delims= " %%a in ('net view ^| find "\\"') do (
	set rhost=%%a
	set rhost=!rhost:\\=!
	rem ping -n 1 -w 500 !rhost!
	for /f "tokens=3-8 delims=-=	 " %%A in ('nbtstat /a !rhost! ^| find "="') do (
		echo !rhost!,%%A%%B%%C%%D%%E%%F>>%Me.Tempfile2%
	)
)
exit /b 0

:_jlmRegLicEnv
%TRACE0% %~0&& rem %
set _var_value=
set op=%~1&& rem %
if not defined op set op=1
if %op% geq 1 (
	if defined ServerPort if defined MyHostName set _var_value=%ServerPort%@%MyHostName%
	if not defined _var_value (
		if exist %Me.Tempfile3%	for /f "tokens=3 delims=," %%a in (%Me.Tempfile3%) do (
			for /f "tokens=2,4" %%A in ("%%a") do (
				if not defined _var_value (
					set _var_value=%%B@%%A
				) else (
					set _var_value=!_var_value!,%%B@%%A
				)
			)
		)
	)
)
setx /?>nul 2>&1 && (
 	setx %JLM_VAR_NAME% "%_var_value%" /m>nul
	exit /b 0
)
call :_jlmInitFile %Me.Tempvbs1%
echo strComputer = ".">>%Me.Tempvbs1%
echo Set objWMIService = GetObject("winmgmts:\\" ^& strComputer ^& "\root\cimv2")>>%Me.Tempvbs1%
echo Set objVariable = objWMIService.Get("Win32_Environment").SpawnInstance_>>%Me.Tempvbs1%
echo objVariable.Name = "%JLM_VAR_NAME%">>%Me.Tempvbs1%
rem echo objVariable.UserName = "%MyHostName%\%USERNAME%">>%Me.Tempvbs1%
echo objVariable.UserName = "<SYSTEM>">>%Me.Tempvbs1%
echo objVariable.VariableValue = "%_var_value%">>%Me.Tempvbs1%
echo objVariable.Put_>>%Me.Tempvbs1%
if exist %SystemRoot%\System32\CScript.exe (
	%SystemRoot%\System32\CScript.exe /B //Nologo %Me.Tempvbs1% && exit /b 0
)
exit /b 1

:_jlmCheckService
%TRACE0% %~0&& rem %
if "%~1"=="" (set _svcname=%DefSvcName%) else (set _svcname="%~1")
sc query %_svcname% | find "1060" >nul && exit /b %L_SC_ERR_NOT_INSTALLED%
set _svcname=
exit /b 0

:_jlmCreateService
%TRACE0% %~0&& rem %
for %%f in (%DefSvcBin%) do if exist %%f set svcbinpath="%%~ff"
set svcname=%DefSvcName:"=%
sc create "%svcname%" binPath= %svcbinpath% start= auto depend= +NetworkProvider DisplayName= %DefSvcDispName%
%TRACE0%.
%TRACE% reg add "HKLM\SOFTWARE\FLEXlm License Manager\%svcname%" /v Lmgrd /t REG_SZ /d %svcbinpath% /f
reg add "HKLM\SOFTWARE\FLEXlm License Manager\%svcname%" /v Lmgrd /t REG_SZ /d %svcbinpath% /f>nul && %TRACE% OK|| %TRACE% NG
%TRACE% reg add "HKLM\SOFTWARE\FLEXlm License Manager\%svcname%" /v License /t REG_SZ /d "%MyLicFile%" /f
reg add "HKLM\SOFTWARE\FLEXlm License Manager\%svcname%" /v License /t REG_SZ /d "%MyLicFile%" /f>nul && %TRACE% OK|| %TRACE% NG
%TRACE% reg add "HKLM\SOFTWARE\FLEXlm License Manager\%svcname%" /v LMGRD_LOG_FILE /t REG_SZ /d "%MyLicFile%%DefLicLogExt%" /f
reg add "HKLM\SOFTWARE\FLEXlm License Manager\%svcname%" /v LMGRD_LOG_FILE /t REG_SZ /d "%MyLicFile%%DefLicLogExt%" /f>nul && %TRACE% OK|| %TRACE% NG
%TRACE% reg add "HKLM\SOFTWARE\FLEXlm License Manager\%svcname%" /v Service /t REG_SZ /d "%svcname%" /f
reg add "HKLM\SOFTWARE\FLEXlm License Manager\%svcname%" /v Service /t REG_SZ /d "%svcname%" /f>nul && %TRACE% OK|| %TRACE% NG
%TRACE% reg add "HKLM\SOFTWARE\FLEXlm License Manager\%svcname%" /v cmdlineparams /t REG_SZ /f
reg add "HKLM\SOFTWARE\FLEXlm License Manager\%svcname%" /v cmdlineparams /t REG_SZ /f>nul && %TRACE% OK|| %TRACE% NG
set svcbinpath=&&set svcname=
exit /b %errorlevel%

:_jlmStartService
%TRACE0% %~0&& rem %
if "%~1"=="" (set _svcname=%DefSvcName%) else (set _svcname="%~1")
net start %_svcname% 2>&1
set _svcname=
exit /b 0

:_jlmStopService
%TRACE0% %~0&& rem %
if "%~1"=="" (set _svcname=%DefSvcName%) else (set _svcname="%~1")
net stop %_svcname% 2>&1 
set _svcname=
exit /b 0

:_jlmDeleteService
%TRACE0% %~0&& rem %
if "%~1"=="" (set _svcname=%DefSvcName%) else (set _svcname="%~1")
sc delete %_svcname% 2>&1
set _svcname=
exit /b 0

:_jlmDeleteSvcRegKey
%TRACE0% %~0&& rem %
if "%~1"=="" (set _svcname=%DefSvcName%) else (set _svcname="%~1")
set _keyname=%_svcname:"=%
%TRACE% reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\FLEXlm License Manager\%_keyname%" /f
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\FLEXlm License Manager\%_keyname%" /f>nul && %TRACE% OK|| %TRACE% NG
exit /b 0

:_jlmListSvc
%TRACE0% %~0&& rem %
call :_jlmInitFile %Me.TempFile1% %Me.TempFile2%
%TRACE% reg export "HKLM\SOFTWARE\FLEXlm License Manager" %Me.Tempfile1%
reg export "HKLM\SOFTWARE\FLEXlm License Manager" %Me.Tempfile1%>nul && %TRACE% OK|| %TRACE% NG
if exist %Me.Tempfile1% type %Me.Tempfile1% | find "=">%Me.Tempfile2%
if not exist %Me.Tempfile2% (
	set Me.ErrNum=%L_JLM_ERR_NO_SERVICE%
	set Me.ErrParam=%1&& rem %
	exit /b %Me.ErrNum%
)
set svccnt=0
for /f "tokens=1,2 delims==" %%a in (%Me.Tempfile2%) do (
	if /i "%%~a"=="License" (
		set licfile=%%b
		set licfile=!licfile:\\=\!
		findstr /i /n /r "DAEMON.*jedat" %%b>nul && set daemonok=1|| set daemonok=
	) else if /i "%%~a"=="LMGRD_LOG_FILE" (
		set logfile=%%b
		set logfile=!logfile:\\=\!
	)
	if defined daemonok (
		 if /i "%%~a"=="Service" (
			echo Service: %%b
			echo          „¥„Ÿ^> Lic: !licfile!
			echo          „¤„Ÿ^> Log: !logfile!
			echo.
			set /a svccnt=!svccnt!+1
		)
	)
)
if %svccnt% equ 0 (
	set Me.ErrNum=%L_JLM_ERR_NO_SERVICE%
	set Me.ErrParam=%1&& rem %
	exit /b %Me.ErrNum%
)
set strsvc=Service
if %svccnt% gtr 1 set strsvc=%strsvc%s
echo Totally Found:%L_TAB%(%svccnt%) %strsvc%
exit /b 0

:_jlmUninstallSvc
%TRACE0% %~0&& rem %
echo Uninstalling %UserServiceName% ...
call :_jlmCheckService %UserServiceName%
set svcsts=%errorlevel%
if %svcsts% equ %L_SC_ERR_NOT_INSTALLED% (
	set Me.ErrNum=%L_JLM_ERR_NO_SERVICE%
	set Me.ErrParam=%UserServiceName%
	exit /b %Me.ErrNum%
)
call :_jlmStopService %UserServiceName%
call :_jlmDeleteService %UserServiceName%
call :_jlmDeleteSvcRegKey %UserServiceName%
call :_jlmRegLicEnv 0
exit /b 0

:_jlmCleanUp
%TRACE0% %~0&& rem %
call :_jlmInitFile %Me.Tempfile1% %Me.Tempfile2% %Me.Tempfile3% %Me.Tempfile4% %Me.Tempvbs1%
exit /b

:_jlmInitFile
%TRACE0% %~0&& rem %
:__nextfile
if "%1"=="" exit /b
if exist "%~fs1" del /f /q "%~fs1"
%TRACE% "%~fs1%"
shift /1
goto __nextfile
exit /b

:_jlmConfigMSWinFirewall
%TRACE0% %~0 %~1
if "%~1"=="" exit /b 1
for %%f in (%DefSvcBin%) do if exist %%f set svcbinpath="%%~ff"
if not defined svcbinpath exit /b 1
for %%f in (%DefDaemon%) do if exist %%f set daemonpath="%%~ff"
if not defined daemonpath exit /b 1
set op=0
if "%~1"=="1" set op=1
set fwcmd=rem
netsh advfirewall>nul && (
	set fwcmd=netsh advfirewall firewall
	if %op% equ 0 (
		%TRACE% !fwcmd! delete rule name=%DefSvcDispName%
		!fwcmd! delete rule name=%DefSvcDispName%>nul && %TRACE% OK || %TRACE% NG
		%TRACE% !fwcmd! delete rule name=%DefDaemonDispName%
		!fwcmd! delete rule name=%DefDaemonDispName%>nul && %TRACE% OK || %TRACE% NG
	) else (
		%TRACE% !fwcmd! add rule name=%DefSvcDispName% dir=in action=allow program=%svcbinpath% description=%DefSvcDispName% profile=private protocol=tcp
		!fwcmd! add rule name=%DefSvcDispName% dir=in action=allow program=%svcbinpath% description=%DefSvcDispName% profile=private protocol=tcp>nul && %TRACE% OK || %TRACE% NG
		%TRACE% !fwcmd! add rule name=%DefDaemonDispName% dir=in action=allow program=%daemonpath% description=%DefDaemonDispName% profile=private protocol=tcp
		!fwcmd! add rule name=%DefDaemonDispName% dir=in action=allow program=%daemonpath% description=%DefDaemonDispName% profile=private protocol=tcp>nul && %TRACE% OK || %TRACE% NG
	)
) || (
	set fwcmd=netsh firewall
	if %op% equ 0 (
		%TRACE% !fwcmd! delete allowedprogram %svcbinpath%
		!fwcmd! delete allowedprogram %svcbinpath%>nul && %TRACE% OK || %TRACE% NG
		%TRACE% !fwcmd! delete allowedprogram %daemonpath%
		!fwcmd! delete allowedprogram %daemonpath%>nul && %TRACE% OK || %TRACE% NG
	) else (
		%TRACE% !fwcmd! add allowedprogram %daemonpath% %DefDaemonDispName% ENABLE
		!fwcmd! add allowedprogram %daemonpath% %DefDaemonDispName% ENABLE>nul && %TRACE% OK || %TRACE% NG
		%TRACE% !fwcmd! add allowedprogram %svcbinpath% %DefSvcDispName% ENABLE
		!fwcmd! add allowedprogram %svcbinpath% %DefSvcDispName% ENABLE>nul && %TRACE% OK || %TRACE% NG
	)
)
set op=&& set fwcmd=
exit /b 0
rem ---- END SUB_ROUTINES ----

:_END
call :_jlmCleanUp
%TRACE0% Me.ErrNum=%Me.ErrNum%
%TRACE0% * END DEBUG:	%DATE% %TIME%
if /i "%Me.Mode%"=="GUI" pause
exit /b %Me.ErrNum%