@echo off
setlocal
chcp 65001 >nul
rem ---------------------------------------------------------------------------
rem  Sufra - builds the Android install file (APK).
rem  Flutter's shader compiler on Windows cannot write into a folder whose path
rem  contains Arabic letters, so the parent folder is mapped to a free drive
rem  letter (pure ASCII path), the app is built there, the APK is copied next
rem  to the project as Sufra.apk, and the mapping is removed.
rem ---------------------------------------------------------------------------
set "HERE=%~dp0"
set "HERE=%HERE:~0,-1%"
for %%I in ("%HERE%") do (
  set "PARENT=%%~dpI"
  set "NAME=%%~nxI"
)
set "PARENT=%PARENT:~0,-1%"
set "DRIVE="
for %%L in (S T U V W X Y Z) do (
  if not defined DRIVE if not exist %%L:\ set "DRIVE=%%L:"
)
if not defined DRIVE (
  echo No free drive letter found.
  exit /b 1
)
subst %DRIVE% "%PARENT%" || exit /b 1
pushd "%DRIVE%\%NAME%"
call flutter build apk --release
set "RESULT=%ERRORLEVEL%"
rem stop Gradle so the mapped drive is no longer in use
pushd android
call gradlew.bat --stop >nul 2>&1
popd
popd
if "%RESULT%"=="0" (
  copy /Y "%HERE%\build\app\outputs\flutter-apk\app-release.apk" "%PARENT%\Sufra.apk" >nul
  echo.
  echo Done: %PARENT%\Sufra.apk
)
subst %DRIVE% /D
exit /b %RESULT%
