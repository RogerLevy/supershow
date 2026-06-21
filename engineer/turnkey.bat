@echo off
setlocal enabledelayedexpansion

if "%1"=="--help" (
    echo Usage: turnkey.bat GAMENAME [FORTH-CODE]
    echo.
    echo Creates release builds of a VFXLand5 game
    echo.
    echo Arguments:
    echo   GAMENAME    Name of the game ^(required^)
    echo   FORTH-CODE  Optional Forth code to execute before save-release
    echo.
    echo Examples:
    echo   turnkey.bat mygame
    echo   turnkey.bat mygame "custom-setup-word"
    exit /b 0
)

@echo on
set "PATH=%~dp0..\bin;%PATH%"

set "baseDir=%CD%"
set "relpath=%1"
set "relpath=%relpath:/=\%"
set "projName=%~n1"

:: Determine the immediate parent folder of the source pathspec
for %%i in ("%relpath%") do set "argDir=%%~dpi"
set "argDir=%argDir:~0,-1%"
for %%i in ("%argDir%") do set "parentName=%%~nxi"

:: Test mode: a test program whose .vfx lives directly under test\
:: All test programs share one master\ + one debug\ folder (one set of DLLs)
set "testMode="
if /i "%parentName%"=="test" if exist "%relpath%.vfx" set "testMode=1"

if defined testMode (goto :testprep) else (goto :normalprep)

:normalprep
:: Absolute paths for Windows file operations (mkdir, copy, del, xcopy)
for %%i in ("%baseDir%\..\rel\%relpath%") do set "releaseDir=%%~fi"
for %%i in ("%baseDir%\..\rel\%relpath%-debug") do set "debugDir=%%~fi"

mkdir "%releaseDir%" 2>nul
mkdir "%debugDir%" 2>nul
del /s /q "%releaseDir%\*.*"
del /s /q "%debugDir%\*.*"

:: Project dat\ lives in the project directory (mirror the source resolution below)
if exist "%relpath%.vfx" (
    for %%i in ("%relpath%") do set "datSrc=%%~dpidat"
) else if exist "%relpath%\main.vfx" (
    set "datSrc=%relpath%\dat"
) else (
    set "datSrc=dat"
)
xcopy "!datSrc!" "%releaseDir%\dat" /i /s /q /y /e
xcopy "!datSrc!" "%debugDir%\dat" /i /s /q /y /e
copy "%~dp0..\bin\*.dll" "%releaseDir%"
copy "%~dp0..\bin\*.dll" "%debugDir%"
(
echo [trace]
echo level=none
) > "%releaseDir%\allegro5.cfg"

:: Relative paths for the compiler (no ".." – they are relative to the script's starting directory)
set "releaseRel=..\rel\%relpath%\%~n1"
set "debugRel=..\rel\%relpath%-debug\%~n1-debug"
goto :outpaths

:testprep
:: Shared output dirs for all test programs: ..\rel\<dir>\master + ..\rel\<dir>\debug
set "relDir=!relpath:\%projName%=!"
for %%i in ("%baseDir%\..\rel\%relDir%\master") do set "releaseDir=%%~fi"
for %%i in ("%baseDir%\..\rel\%relDir%\debug") do set "debugDir=%%~fi"

mkdir "%releaseDir%" 2>nul
mkdir "%debugDir%" 2>nul
:: Update the shared dat\ (incremental); no wipe so other test exes survive
xcopy "%relDir%\dat" "%releaseDir%\dat" /i /s /q /y /e /d
xcopy "%relDir%\dat" "%debugDir%\dat" /i /s /q /y /e /d
:: Copy DLLs only when missing or newer (/d) – they're shared, no re-duplication
xcopy "%~dp0..\bin\*.dll" "%releaseDir%\" /i /q /y /d
xcopy "%~dp0..\bin\*.dll" "%debugDir%\" /i /q /y /d
(
echo [trace]
echo level=none
) > "%releaseDir%\allegro5.cfg"

set "releaseRel=..\rel\%relDir%\master\%projName%"
set "debugRel=..\rel\%relDir%\debug\%projName%-debug"
goto :outpaths

:outpaths
:: Convert backslashes to forward slashes to be extra safe in Forth
set "releaseRel=%releaseRel:\=/%"
set "debugRel=%debugRel:\=/%"

:: Compiler flags – keep them short
set "configString=debug off validations off safety off turnkey-mode on"

:: Determine source file – use forward slashes for the Forth parser
if exist %1.vfx (
    set "source=include %1.vfx"
    set "source=!source:\=/!"
) else if exist %1\main.vfx (
    set "source=include %1\main.vfx"
    set "source=!source:\=/!"
) else if exist main.vfx (
    set "source=^^ main"
) else (
    set "source=^^ engineer"
)

:: Execute the compiler with relative output paths (and optional Forth code)
if "%2"=="" (
    engineer.exe %configString% %source% turnkey-mode off save-release %releaseRel% save-debug %debugRel%
) else (
    engineer.exe %configString% %source% %2 turnkey-mode off save-release %releaseRel% save-debug %debugRel%
)