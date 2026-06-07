@echo off
set "PATH=%~dp0..\bin;%PATH%"
if exist main.vfx (
    echo Loading project from %cd%
    engineer.exe ^^ main %* ^>vfx
) else (
    echo No main.vfx found, starting Engineer normally
    engineer.exe ^^ engineer %* ^>vfx
)