@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "CONF_FILE=%SCRIPT_DIR%find_herdr_versions.conf"

echo.
echo ===============================================================================
echo  VERSION    PATH
echo ===============================================================================

if not "%~1"=="" (
    call :scan_dir "%~1"
) else if exist "%CONF_FILE%" (
    for /f "usebackq eol=# tokens=*" %%R in ("%CONF_FILE%") do (
        set "TARGET_DIR=%%~R"
        if defined TARGET_DIR (
            if exist "!TARGET_DIR!" (
                call :scan_dir "!TARGET_DIR!"
            ) else (
                set "ERR_PAD=[MISSING]   "
                echo  !ERR_PAD:~0,10! Path does not exist: !TARGET_DIR!
            )
        )
    )
) else (
    call :scan_dir "."
)

echo ===============================================================================
echo.

pause
exit /b 0

:scan_dir
set "SEARCH_PATH=%~1"
for /r "%SEARCH_PATH%" %%F in (herdr.bat) do (
    if exist "%%F" (
        set "VER=NOT_FOUND"
        for /f "tokens=3" %%V in ('findstr /b /c:":: Version:" "%%F" 2^>nul') do (
            set "VER=%%V"
        )
        set "VER_PAD=!VER!          "
        set "VER_PAD=!VER_PAD:~0,10!"
        echo  !VER_PAD! %%F
    )
)
exit /b 0


