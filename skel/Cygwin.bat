@echo off
setlocal enableextensions

set PATH=%~dp0bin;%PATH%
rem mintty.exe -i /Cygwin-Terminal.ico -
bash.exe --login -i
