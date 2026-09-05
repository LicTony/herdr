@echo off
chcp 65001 >nul 2>&1
setlocal EnableExtensions EnableDelayedExpansion
:: herdr.bat - toggle workspace (Windows port of herdr.sh)
:: Version: 2.0.0
:: Last modified: 2026-09-05
:: Tab sources (in order):
::   1. Global: %HERDR_GLOBAL_FILE% or %USERPROFILE%\herdrglobal  (TSV: label<TAB>command)
::   2. Local:  herdr.tabs in the project dir                      (same TSV format, optional)

:: --- Version ---
set "VERSION="
for /f "tokens=3" %%v in ('findstr /b /c:":: Version:" "%~f0"') do set "VERSION=%%v"
if not defined VERSION set "VERSION=2.0.0"
echo herdr v!VERSION!

:: --- Project dir and label ---
set "PROYECTO_DIR=%~dp0"
if "!PROYECTO_DIR:~-1!"=="\" set "PROYECTO_DIR=!PROYECTO_DIR:~0,-1!"
for %%I in ("!PROYECTO_DIR!") do set "LABEL=%%~nxI"

:: --- Global / Local TSV paths ---
if defined HERDR_GLOBAL_FILE (
  set "GLOBAL_TABS_FILE=%HERDR_GLOBAL_FILE%"
  echo HERDR_GLOBAL_FILE=%HERDR_GLOBAL_FILE%
) else (
  set "GLOBAL_TABS_FILE=%USERPROFILE%\herdrglobal"
  1>&2 echo herdr: warning: HERDR_GLOBAL_FILE no esta definida, usando default: !GLOBAL_TABS_FILE!
  1>&2 echo herdr: tip: ejecuta 'setx HERDR_GLOBAL_FILE "C:\ruta\al\archivo"' y reinicia la terminal
)
set "LOCAL_TABS_FILE=!PROYECTO_DIR!\herdr.tabs"

:: --- Dependencies ---
set "HERDR_BIN="
for /f "delims=" %%I in ('where herdr 2^>nul') do set "HERDR_BIN=%%I"
if not defined HERDR_BIN (
  1>&2 echo herdr: error: herdr no encontrado en PATH
  1>&2 echo herdr: tip: instala herdr y asegurate que este en PATH
  exit /b 1
)
where jq >nul 2>nul
if errorlevel 1 (
  1>&2 echo herdr: error: jq no encontrado en PATH. Instala con 'winget install jqlang.jq'
  exit /b 1
)
set "HAS_POWERSHELL="
where powershell >nul 2>nul
if not errorlevel 1 set "HAS_POWERSHELL=1"
if not defined HAS_POWERSHELL (
  where pwsh >nul 2>nul
  if not errorlevel 1 set "HAS_POWERSHELL=1"
)

:: --- Find existing workspace by label (avoid pipe in for /f; use temp file) ---
set "WS_ID="
set "TAB_COUNT="
set "WS_LIST_TMP=%TEMP%\herdr_wslist_%RANDOM%.json"
"%HERDR_BIN%" workspace list > "!WS_LIST_TMP!" 2>nul
for /f "delims=" %%I in ('jq -r --arg label "!LABEL!" "[.result.workspaces[] | select(.label == $label)] | first // empty | .workspace_id // empty" "!WS_LIST_TMP!"') do set "WS_ID=%%I"
 if defined WS_ID (
  for /f "delims=" %%I in ('jq -r --arg label "!LABEL!" "[.result.workspaces[] | select(.label == $label)] | first // empty | .tab_count // empty" "!WS_LIST_TMP!"') do set "TAB_COUNT=%%I"
)

set "TAB_ROOT="
set "PANE_AGENTE="
set "WS_JSON_TMP=%TEMP%\herdr_ws_%RANDOM%.json"
set "TAB_LIST_TMP=%TEMP%\herdr_tablist_%RANDOM%.json"
set "PANE_LIST_TMP=%TEMP%\herdr_panelist_%RANDOM%.json"

if defined WS_ID (
  if "!TAB_COUNT!"=="" set "TAB_COUNT=0"
  if !TAB_COUNT! GTR 1 (
    "%HERDR_BIN%" workspace close "!WS_ID!"
    echo Workspace '!LABEL!' ^(id=!WS_ID!^) cerrado.
    if exist "!WS_JSON_TMP!" del /f /q "!WS_JSON_TMP!" >nul 2>nul
    if exist "!WS_LIST_TMP!" del /f /q "!WS_LIST_TMP!" >nul 2>nul
    if exist "!TAB_LIST_TMP!" del /f /q "!TAB_LIST_TMP!" >nul 2>nul
    if exist "!PANE_LIST_TMP!" del /f /q "!PANE_LIST_TMP!" >nul 2>nul
    endlocal
    exit /b 0
  )
  echo Workspace '!LABEL!' existe con 1 tab, poblando...
  "%HERDR_BIN%" tab list --workspace "!WS_ID!" > "!TAB_LIST_TMP!" 2>nul
  for /f "delims=" %%I in ('jq -r ".result.tabs[0].tab_id // empty" "!TAB_LIST_TMP!"') do set "TAB_ROOT=%%I"
  if not defined TAB_ROOT (
    1>&2 echo herdr: error: no se pudo obtener TAB_ROOT para workspace !WS_ID!
    exit /b 1
  )
  "%HERDR_BIN%" pane list --workspace "!WS_ID!" > "!PANE_LIST_TMP!" 2>nul
  for /f "delims=" %%I in ('jq -r --arg tab "!TAB_ROOT!" "[.result.panes[] | select(.tab_id == $tab) | .pane_id][0] // empty" "!PANE_LIST_TMP!"') do set "PANE_AGENTE=%%I"
  if not defined PANE_AGENTE (
    for /f "delims=" %%I in ('jq -r ".result.panes[0].pane_id // empty" "!PANE_LIST_TMP!"') do set "PANE_AGENTE=%%I"
  )
  if not defined PANE_AGENTE (
    1>&2 echo herdr: error: no se pudo obtener PANE_AGENTE para workspace !WS_ID!
    exit /b 1
  )
  "%HERDR_BIN%" tab rename "!TAB_ROOT!" "terminal" >nul
  "%HERDR_BIN%" pane run "!PANE_AGENTE!" "cmd.exe" >nul
  if exist "!TAB_LIST_TMP!" del /f /q "!TAB_LIST_TMP!" >nul 2>nul
  if exist "!PANE_LIST_TMP!" del /f /q "!PANE_LIST_TMP!" >nul 2>nul
) else (
  "%HERDR_BIN%" workspace create --cwd "!PROYECTO_DIR!" --label "!LABEL!" > "!WS_JSON_TMP!" 2>&1
  if errorlevel 1 (
    1>&2 echo herdr: error: fallo al crear workspace '!LABEL!'
    if exist "!WS_JSON_TMP!" type "!WS_JSON_TMP!" 1>&2
    exit /b 1
  )
  for /f "delims=" %%I in ('jq -r ".result.workspace.workspace_id // empty" "!WS_JSON_TMP!"') do set "WS_ID=%%I"
  for /f "delims=" %%I in ('jq -r ".result.root_pane.tab_id // empty" "!WS_JSON_TMP!"') do set "TAB_ROOT=%%I"
  for /f "delims=" %%I in ('jq -r ".result.root_pane.pane_id // empty" "!WS_JSON_TMP!"') do set "PANE_AGENTE=%%I"
  if not defined WS_ID (
    1>&2 echo herdr: error: no se pudo parsear workspace_id de la respuesta
    if exist "!WS_JSON_TMP!" type "!WS_JSON_TMP!" 1>&2
    exit /b 1
  )
  if defined TAB_ROOT "%HERDR_BIN%" tab rename "!TAB_ROOT!" "terminal" >nul
  if defined PANE_AGENTE "%HERDR_BIN%" pane run "!PANE_AGENTE!" "cmd.exe" >nul
  if exist "!WS_JSON_TMP!" del /f /q "!WS_JSON_TMP!" >nul 2>nul
)
if exist "!WS_LIST_TMP!" del /f /q "!WS_LIST_TMP!" >nul 2>nul

:: --- Create auxiliary tabs ---
set "TAB_LABELS=opencode"
if exist "!GLOBAL_TABS_FILE!" (
  call :LOAD_TABS_FROM_FILE "!GLOBAL_TABS_FILE!"
  call :APPEND_LABELS "!GLOBAL_TABS_FILE!"
) else (
  1>&2 echo herdr: warning: archivo global no encontrado: !GLOBAL_TABS_FILE!
  1>&2 echo herdr: tip: crea el archivo o defini HERDR_GLOBAL_FILE en tu shell.
)
if exist "!LOCAL_TABS_FILE!" (
  call :LOAD_TABS_FROM_FILE "!LOCAL_TABS_FILE!"
  call :APPEND_LABELS "!LOCAL_TABS_FILE!"
)

echo Workspace '!LABEL!' creado. id=!WS_ID!
echo Tabs: !TAB_LABELS!
"%HERDR_BIN%" workspace focus "!WS_ID!" >nul
endlocal
exit /b 0

:: ============================================================
:: :LOAD_TABS_FROM_FILE  %1 = full path to TSV file
:: Hybrid: PowerShell if available (robust TAB/UTF-8/CRLF), else batch pure fallback
:: ============================================================
:LOAD_TABS_FROM_FILE
set "TSV_FILE=%~1"
if not exist "%~1" exit /b 0
if defined HAS_POWERSHELL goto :LOAD_TABS_PS
goto :LOAD_TABS_BATCH

:LOAD_TABS_PS
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='SilentlyContinue'; $f='%TSV_FILE%'; $ws=$env:WS_ID; $n=0; Get-Content -LiteralPath $f -Encoding utf8 | ForEach-Object { $n++; $line=$_; $trimmed=$line.Trim(); if($trimmed -eq '' -or $trimmed -match '^#'){ return }; if($line -notmatch \"`t\"){ Write-Host \"herdr: warning: ${f}:${n}: linea malformada (sin TAB), se ignora: '$line'\"; return }; $parts=$line.Split(\"`t\",2); $label=$parts[0]; $cmd=$parts[1]; if([string]::IsNullOrWhiteSpace($label) -or [string]::IsNullOrWhiteSpace($cmd)){ Write-Host \"herdr: warning: ${f}:${n}: linea malformada (sin TAB), se ignora: '$line'\"; return }; try { $j = herdr tab create --workspace $ws --label $label --no-focus 2>&1 | Out-String; $obj = $j | ConvertFrom-Json; $pane=$obj.result.root_pane.pane_id; if($pane){ herdr pane run $pane $cmd | Out-Null } } catch { Write-Host \"herdr: warning: fallo al crear tab '$label': $_\" } }"
exit /b 0

:LOAD_TABS_BATCH
set /a LINE_NUM=0
for /f "usebackq eol= delims=" %%L in ("%TSV_FILE%") do (
  set /a LINE_NUM+=1
  set "LINE=%%L"
  set "SKIP="
  for /f "tokens=*" %%T in ("!LINE!") do set "TRIMMED=%%T"
  if not defined TRIMMED set "SKIP=1"
  if not defined SKIP if "!TRIMMED:~0,1!"=="#" set "SKIP=1"
  if not defined SKIP (
    for /f "tokens=1,* delims=	" %%A in ("!LINE!") do (
      if "%%B"=="" (
        1>&2 echo herdr: warning: !TSV_FILE!:!LINE_NUM!: linea malformada (sin TAB), se ignora: '!LINE!'
      ) else (
        set "TAB_LABEL=%%A"
        set "TAB_CMD=%%B"
        rem for /f already strips trailing CR - no extra trim needed
        call :CREATE_TAB
      )
    )
  )
)
exit /b 0

:CREATE_TAB
if not defined TAB_LABEL exit /b 0
if not defined TAB_CMD exit /b 0
set "TMP_JSON=%TEMP%\herdr_tab_%RANDOM%.json"
"%HERDR_BIN%" tab create --workspace "!WS_ID!" --label "!TAB_LABEL!" --no-focus > "!TMP_JSON!" 2>&1
if errorlevel 1 (
  1>&2 echo herdr: warning: fallo al crear tab '!TAB_LABEL!'
  if exist "!TMP_JSON!" del /f /q "!TMP_JSON!" >nul 2>nul
  exit /b 0
)
set "PANE_ID="
for /f "delims=" %%I in ('jq -r ".result.root_pane.pane_id // empty" "!TMP_JSON!"') do set "PANE_ID=%%I"
if defined PANE_ID (
  "%HERDR_BIN%" pane run "!PANE_ID!" "!TAB_CMD!" >nul 2>&1
) else (
  1>&2 echo herdr: warning: no se pudo obtener pane_id para tab '!TAB_LABEL!'
)
if exist "!TMP_JSON!" del /f /q "!TMP_JSON!" >nul 2>nul
exit /b 0

:APPEND_LABELS
set "AFILE=%~1"
if not exist "%~1" exit /b 0
for /f "usebackq eol= delims=" %%L in ("%AFILE%") do (
  set "ALINE=%%L"
  for /f "tokens=*" %%T in ("!ALINE!") do set "ATRIM=%%T"
  if defined ATRIM if not "!ATRIM:~0,1!"=="#" (
    for /f "tokens=1,* delims=	" %%X in ("!ALINE!") do if not "%%Y"=="" set "TAB_LABELS=!TAB_LABELS! | %%X"
  )
)
exit /b 0
