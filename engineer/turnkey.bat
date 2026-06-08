@echo off

echo DEBUG: %1

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
set "relpath=%1"
set "relpath=%relpath:/=\%"

mkdir ..\rel\%relpath%
mkdir ..\rel\%relpath%-debug
del ..\rel\%relpath%\*.* /s /q
del ..\rel\%relpath%-debug\*.* /s /q
xcopy dat ..\rel\%relpath%\dat /i /s /q /y /e
xcopy dat ..\rel\%relpath%-debug\dat /i /s /q /y /e
copy %~dp0\..\bin\*.dll ..\rel\%relpath%
copy %~dp0\..\bin\*.dll ..\rel\%relpath%-debug
(
echo [trace]
echo level=none
) > ..\rel\%relpath%\allegro5.cfg

SET saveString=%2 turnkey-mode off save-release ..\rel\%relpath%\%~n1 save-debug ..\rel\%relpath%-debug\%~n1-debug
SET configString=debug off validations off safety off turnkey-mode on

if exist %1.vfx (
    engineer.exe %configString% include %1.vfx %saveString%
) else if exist %1\main.vfx (
    engineer.exe %configString% ldp %1 %saveString%
) else if exist main.vfx (
    engineer.exe %configString% ^^ main %saveString%
) else (
    engineer.exe %configString% ^^ engineer %saveString%
)
