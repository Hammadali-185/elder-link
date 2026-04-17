@echo off
rem This file was created by pub v3.11.1.
rem Package: flutterfire_cli
rem Version: 1.3.2
rem Executable: flutterfire
rem Script: flutterfire
set "FLUTTERFIRE_SNAPSHOT=%LOCALAPPDATA%\Pub\Cache\global_packages\flutterfire_cli\bin\flutterfire.dart-3.11.1.snapshot"
if exist "%FLUTTERFIRE_SNAPSHOT%" (
  call dart "%FLUTTERFIRE_SNAPSHOT%" %*
  rem The VM exits with code 253 if the snapshot version is out-of-date.
  rem If it is, we need to delete it and run "pub global" manually.
  if not errorlevel 253 (
    goto error
  )
  call dart pub global run flutterfire_cli:flutterfire %*
) else (
  call dart pub global run flutterfire_cli:flutterfire %*
)
goto eof
:error
exit /b %errorlevel%
:eof
