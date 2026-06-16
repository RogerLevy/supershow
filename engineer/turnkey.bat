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

:: Absolute paths for Windows file operations (mkdir, copy, del, xcopy)
for %%i in ("%baseDir%\..\rel\%relpath%") do set "releaseDir=%%~fi"
for %%i in ("%baseDir%\..\rel\%relpath%-debug") do set "debugDir=%%~fi"

mkdir "%releaseDir%" 2>nul
mkdir "%debugDir%" 2>nul
del /s /q "%releaseDir%\*.*"
del /s /q "%debugDir%\*.*"
xcopy dat "%releaseDir%\dat" /i /s /q /y /e
xcopy dat "%debugDir%\dat" /i /s /q /y /e
copy "%~dp0..\bin\*.dll" "%releaseDir%"
copy "%~dp0..\bin\*.dll" "%debugDir%"
(
echo [trace]
echo level=none
) > "%releaseDir%\allegro5.cfg"

:: Compiler flags – keep them short
set "configString=debug off validations off safety off turnkey-mode on"

:: Relative paths for the compiler (no ".." – they are relative to the script's starting directory)
set "releaseRel=..\rel\%relpath%\%~n1"
set "debugRel=..\rel\%relpath%-debug\%~n1-debug"
:: Convert backslashes to forward slashes to be extra safe in Forth
set "releaseRel=%releaseRel:\=/%"
set "debugRel=%debugRel:\=/%"

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