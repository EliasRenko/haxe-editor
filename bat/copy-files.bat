@echo off
setlocal

set SOURCE=%~1
set DEST=%~2

if not exist "%SOURCE%" (
    echo Source directory does not exist: %SOURCE%
    exit /b 1
)

if not exist "%DEST%" (
    mkdir "%DEST%"
)

xcopy "%SOURCE%" "%DEST%" /E /I /Y /Q

exit /b 0
