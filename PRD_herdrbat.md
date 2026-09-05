# PRD: herdr.bat — Port de herdr.sh a Windows (Batch)

**Date:** 2026-09-05
**Author:** Tony / gentle-orchestrator
**Status:** Draft
**Source of truth:** `herdr.sh` v2.0.0 (2026-08-14)
**Target:** `herdr.bat` — toggle workspace para Windows (cmd.exe)
**Replaces / complements:** `herdr.sh` (Linux/macOS Bash) → equivalente nativo Windows

---

## 1. Resumen Ejecutivo

`herdr.sh` es un script Bash que hace toggle de workspaces de HERDR: si el workspace del proyecto ya existe y tiene >1 tab lo cierra; si tiene 1 tab lo puebla; si no existe lo crea. Luego crea tabs auxiliares desde dos fuentes TSV (`%HERDR_GLOBAL_FILE%` y `herdr.tabs`).

Hoy `herdr.sh` no corre en Windows. El objetivo es entregar `herdr.bat` con **paridad funcional 1:1** para que un desarrollador en Windows haga doble-click o `herdr.bat` desde `cmd.exe`/`PowerShell` y obtenga el mismo workspace que en Linux, sin instalar WSL/Git Bash.

> Nota: el usuario pidió `PRD_herdsbat.md` — se entrega como `PRD_herdrbat.md` (nombre canónico). Si necesitás el alias con `s`, duplicá el archivo.

---

## 2. Problema

- `herdr.sh` usa `bash`, `jq`, `grep`, `awk`, `sed`, expansión `${VAR:-default}`, `BASH_SOURCE`, `pipefail`, `herdr workspace/tab/pane` con JSON — nada de eso existe nativo en `cmd.exe`.
- Usuarios Windows hoy dependen de WSL o Git Bash, lo que rompe flujos `cmd`/`PowerShell` y el auto-start de HERDR en Windows.
- Sin port, cada proyecto necesita instrucciones distintas por OS.

---

## 3. Objetivos

### 3.1 Objetivo primario
Entregar `herdr.bat` que replique el comportamiento de `herdr.sh` v2.0.0 en Windows 10/11 con `cmd.exe` nativo, sin dependencias opcionales más allá de `herdr.exe` y un parser JSON.

### 3.2 Objetivos secundarios
- Mantener el mismo contrato de archivos TSV (`label<TAB>command`).
- Respetar `HERDR_GLOBAL_FILE` con fallback a `%USERPROFILE%\herdrglobal`.
- Soportar `herdr.tabs` local opcional en el dir del proyecto.
- Mensajes y warnings equivalentes (stderr) para diagnóstico.

### 3.3 No-objetivos (v1 de herdr.bat)
- No reescribir en PowerShell (se evalúa como `herdr.ps1` futuro).
- No agregar UI/wizard para editar tabs.
- No soportar expansión de variables dentro de comandos (`%VAR%` literal).
- No tabs condicionales (ej. "solo si existe docker-compose.yml").
- No deduplicación automática de labels (mismo criterio que v2.0.0).

---

## 4. Usuarios y Casos de Uso

| Persona | Contexto | Job-to-be-done |
|---|---|---|
| Dev Windows puro | Usa `cmd.exe` o PowerShell, sin WSL | `herdr.bat` desde el dir del proyecto → workspace poblado |
| Dev cross-platform | Mismo repo en Linux y Windows | Mismo `herdr.tabs` commiteado funciona en ambos OS |
| Dev con dotfiles | Tiene `herdrglobal` versionado | `setx HERDR_GLOBAL_FILE` apunta a su dotfiles en Windows |

**Caso principal:**
```bat
C:\Tony\mi-proyecto> herdr.bat
herdr v2.0.0
Workspace 'mi-proyecto' creado. id=abc123
Tabs: opencode | pi | git | dev | logs
```

---

## 5. Requisitos Funcionales

### 5.1 Paridad de comportamiento toggle

Debe replicar exactamente la tabla de `manualherdrsh.md`:

| Situación | Resultado |
|---|---|
| No existe workspace para el proyecto (label = nombre del dir) | `herdr workspace create --cwd <PROYECTO_DIR> --label <LABEL>` + poblar tabs |
| Existe con `tab_count == 1` | Poblar: renombrar tab raíz a `terminal`, `herdr pane run <pane_id> cmd.exe` (o `bash` si está disponible), luego crear tabs auxiliares |
| Existe con `tab_count > 1` | `herdr workspace close <WS_ID>` y salir con `exit /b 0` (toggle off) |

Label = `basename` del directorio que contiene `herdr.bat` (equivalente a `basename "$PROYECTO_DIR"`).

### 5.2 Versionado

- Primera línea del `.bat` debe declarar versión en comentario parseable:
  ```bat
  :: herdr.bat — toggle workspace (Windows port of herdr.sh)
  :: Version: 2.0.0
  :: Last modified: 2026-09-05
  ```
- Al arrancar, imprimir `herdr v2.0.0` (extraído del comentario o hardcodeado). Mantener sincronizado con `herdr.sh`.

### 5.3 Resolución de paths

| Concepto | Linux (`herdr.sh`) | Windows (`herdr.bat`) |
|---|---|---|
| Dir del proyecto | `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)` | `%~dp0` normalizado sin trailing `\` |
| Label | `basename "$PROYECTO_DIR"` | último segmento de `%~dp0` |
| Global default | `${HOME}/herdrglobal` | `%USERPROFILE%\herdrglobal` |
| Global env var | `${HERDR_GLOBAL_FILE:-${HOME}/herdrglobal}` | `%HERDR_GLOBAL_FILE%` si definida, sino `%USERPROFILE%\herdrglobal` |
| Local | `${PROYECTO_DIR}/herdr.tabs` | `%PROYECTO_DIR%\herdr.tabs` |

Reglas:
- Si `HERDR_GLOBAL_FILE` está definida → `echo HERDR_GLOBAL_FILE=%HERDR_GLOBAL_FILE%`
- Si no está definida → `echo herdr: warning: HERDR_GLOBAL_FILE no esta definida, usando default: <path> >&2` + tip para `setx`.

### 5.4 Formato de archivos TSV

Idéntico a `herdr.sh` v2:

```
# comentario — se ignora
<línea vacía> — se ignora

<label><TAB><comando>
```

- Separador: TAB real (`0x09`), no espacios.
- `label` puede contener espacios (`opencode 2` válido, sin comillas).
- `comando` es literal, se pasa a `herdr pane run <pane_id> "<comando>"`.
- Líneas sin TAB → `herdr: warning: <file>:<n>: linea malformada (sin TAB), se ignora: '<line>' >&2`, se skipea.
- Orden de líneas = orden de creación de tabs.
- Orden final: `[terminal] → [tabs de GLOBAL] → [tabs de herdr.tabs local]`.

### 5.5 Creación de tabs

Función `create_tab` equivalente:

```bat
:CREATE_TAB
:: %1 = label, %2 = comando
herdr tab create --workspace %WS_ID% --label "%~1" --no-focus
:: parsear JSON para pane_id y luego: herdr pane run %PANE_ID% "%~2"
```

Debe ser `--no-focus` para no robar foco, igual que en `.sh`.

Tab raíz:
- `herdr tab list --workspace %WS_ID%` → primer `tab_id`
- `herdr pane list --workspace %WS_ID%` → `pane_id` donde `tab_id == TAB_ROOT` (primer match)
- `herdr tab rename %TAB_ROOT% "terminal"`
- `herdr pane run %PANE_AGENTE% "cmd.exe"`  (ver §5.7)

### 5.6 Dependencia JSON: `jq` en Windows

`herdr.sh` usa `jq` intensivamente. En Windows hay tres opciones — el PRD debe elegir una:

**Opción A (recomendada): `jq.exe` portable (paridad total)**
- Requerir `jq` en PATH (winget: `winget install jqlang.jq`, o `choco install jq`, o binario portable junto a `herdr.bat`).
- Si `jq` no está → error claro: `herdr: error: jq no encontrado en PATH. Instala con 'winget install jqlang.jq' >&2` y `exit /b 1`.
- Ventaja: parsing idéntico a Linux, menos riesgo.

**Opción B: PowerShell como parser JSON (sin jq)**
- Usar `powershell -NoProfile -Command "(herdr workspace list | ConvertFrom-Json).result.workspaces | Where-Object label -eq '%LABEL%' ..."`
- Ventaja: sin dependencia extra en Windows 10/11 (PowerShell 5.1+ viene preinstalado).
- Desventaja: más lento, quoting complejo, requiere validar en `cmd.exe`.

**Opción C: híbrido**
- Intentar `jq` primero; si no existe, fallback a PowerShell. Complejidad extra pero mejor UX.

> **Decisión propuesta:** Opción A para v1 (simple, testeable), documentar Opción B como mejora v1.1. El `.bat` debe detectar `where jq >nul 2>nul` al inicio.

### 5.7 Shell del pane raíz

`herdr.sh` hace `herdr pane run "$PANE_AGENTE" "bash"`. En Windows:

- Default: `cmd.exe` (siempre disponible).
- Si `bash.exe` está en PATH (Git Bash), usar `bash` es opcional pero no default.
- El comando del tab `terminal` es configurable: si `herdrglobal` ya trae un tab `terminal`, no duplicar; el tab raíz es el `terminal` ancla.
- Documentar: usuarios que quieran `powershell.exe` o `pwsh.exe` pueden poner `terminal<TAB>powershell` en `herdrglobal` y el script no debe hardcodear `bash`.

Propuesta v1: `herdr pane run %PANE_AGENTE% "cmd.exe"` tras renombrar a `terminal`.

### 5.8 Mensajes y logging

Réplica de `herdr.sh`:

- `herdr v2.0.0` a stdout al inicio.
- `HERDR_GLOBAL_FILE=...` si definida.
- Warnings a stderr (`1>&2` en batch: `1>&2 echo ...`):
  - `herdr: warning: HERDR_GLOBAL_FILE no esta definida, usando default: ...`
  - `herdr: warning: archivo global no encontrado: ...`
  - `herdr: warning: <file>:<n>: linea malformada (sin TAB), se ignora: '...'`
  - Tips equivalentes a `tip: crea el archivo o defini HERDR_GLOBAL_FILE...`
- Éxito: `Workspace '<LABEL>' creado. id=<WS_ID>` + `Tabs: opencode | ...` + focus.

### 5.9 Focus final

`herdr workspace focus %WS_ID%` siempre al final del flujo create/populate (no en toggle-off).

---

## 6. Requisitos No Funcionales

| Aspecto | Requisito |
|---|---|
| Compatibilidad | Windows 10 22H2+, Windows 11, `cmd.exe` nativo. No requiere WSL. |
| Encoding | Archivos TSV en UTF-8 sin BOM (igual que Linux). El `.bat` debe ser ANSI o UTF-8 sin BOM con `chcp 65001 >nul` opcional. |
| Line endings | Soportar `CRLF` y `LF` al leer TSV (batch `for /f` lo hace, pero validar). |
| Performance | <2s overhead además de llamadas `herdr` (igual que `.sh`). |
| Seguridad | `setlocal EnableDelayedExpansion` y `setlocal EnableExtensions`, no `eval` de comandos locales. |
| Mantenibilidad | Comentarios `::` equivalentes a los de `herdr.sh`, bloques `:FUNCION`. |

---

## 7. Diseño Técnico Propuesto

### 7.1 Esqueleto `herdr.bat`

```bat
@echo off
setlocal EnableExtensions EnableDelayedExpansion
:: herdr.bat — toggle workspace (Windows port of herdr.sh)
:: Version: 2.0.0
:: Last modified: 2026-09-05

:: 1. Version
for /f "tokens=3" %%v in ('findstr /b ":: Version:" "%~f0"') do set "VERSION=%%v"
echo herdr v%VERSION%

:: 2. Paths
set "PROYECTO_DIR=%~dp0"
:: quitar trailing \
if "%PROYECTO_DIR:~-1%"=="\" set "PROYECTO_DIR=%PROYECTO_DIR:~0,-1%"
for %%I in ("%PROYECTO_DIR%") do set "LABEL=%%~nxI"

if defined HERDR_GLOBAL_FILE (
  set "GLOBAL_TABS_FILE=%HERDR_GLOBAL_FILE%"
  echo HERDR_GLOBAL_FILE=%HERDR_GLOBAL_FILE%
) else (
  set "GLOBAL_TABS_FILE=%USERPROFILE%\herdrglobal"
  1>&2 echo herdr: warning: HERDR_GLOBAL_FILE no esta definida, usando default: %GLOBAL_TABS_FILE%
  1>&2 echo herdr: tip: ejecuta 'setx HERDR_GLOBAL_FILE "C:\ruta\al\archivo"' y reinicia la terminal
)

set "LOCAL_TABS_FILE=%PROYECTO_DIR%\herdr.tabs"

:: 3. Dependencias
where jq >nul 2>nul
if errorlevel 1 (
  1>&2 echo herdr: error: jq no encontrado en PATH. Instala con 'winget install jqlang.jq'
  exit /b 1
)
where herdr >nul 2>nul
if errorlevel 1 (
  1>&2 echo herdr: error: herdr no encontrado en PATH
  exit /b 1
)

:: 4. Buscar workspace por label (herdr workspace list | jq)
:: 5. Branch: toggle-off / populate / create
:: 6. Crear tabs auxiliares via :LOAD_TABS_FROM_FILE
:: 7. Focus
```

### 7.2 Parsing TSV en Batch (punto crítico)

Batch no tiene `IFS= read -r` ni regex nativo. Opciones:

**Opción recomendada: delegar parsing a PowerShell inline (robusto):**
```bat
:LOAD_TABS_FROM_FILE
:: %1 = path al archivo TSV
set "FILE=%~1"
set /a LINE_NUM=0
for /f "usebackq delims=" %%L in ("%FILE%") do (
  set /a LINE_NUM+=1
  set "LINE=%%L"
  :: saltar comentarios y vacías via findstr / powershell
)
```
Pero `for /f` tokeniza por defecto y pierde TABs. Mejor:

```bat
powershell -NoProfile -Command ^
  "$n=0; Get-Content -LiteralPath '%FILE%' | ForEach-Object { $n++; $l=$_; if($l -match '^\s*#' -or $l -match '^\s*$'){return} if($l -notmatch \"`t\"){ Write-Host \"herdr: warning: ${FILE}:$n: linea malformada (sin TAB), se ignora: '$l'\" -ForegroundColor Yellow; return } $label=$l.Split(\"`t\",2)[0]; $cmd=$l.Split(\"`t\",2)[1]; herdr tab create --workspace $env:WS_ID --label $label --no-focus | Out-Null }"
```

Simplificación: el `.bat` invoca un helper PowerShell de una línea para cada archivo. Esto evita reimplementar TSV parsing frágil en batch puro.

**Alternativa batch puro (si se exige sin PowerShell):**
- Usar `findstr /v "^#" "%FILE%"` para filtrar comentarios, luego `for /f "tokens=1,* delims=	" %%A in (...)` donde `delims` es un TAB literal (insertado con editor que preserve TAB). Frágil pero posible. Requiere que el `.bat` se guarde con TAB real en esa línea.

> **Decisión propuesta:** v1 usa helper PowerShell para TSV (disponible en todo Windows), documentado como dependencia implícita. Si el equipo exige batch 100% puro, se deja como variante documentada en §9.

### 7.3 Manejo de JSON

Con `jq`:
```bat
for /f "delims=" %%I in ('herdr workspace list ^| jq -r --arg label "%LABEL%" "[.result.workspaces[] | select(.label == $label)] | first // empty"') do set "WS_INFO=%%I"
```

Sin `jq` (fallback PowerShell):
```bat
for /f "delims=" %%I in ('powershell -NoProfile -Command "(herdr workspace list | ConvertFrom-Json).result.workspaces | Where-Object { $_.label -eq '%LABEL%' } | Select-Object -First 1 | ConvertTo-Json -Compress"') do set "WS_INFO=%%I"
```

---

## 8. Instalación y Uso (Windows)

### 8.1 Instalación binaria HERDR en Windows

```powershell
# PowerShell (winget — recomendado)
winget install herdr

# O descarga directa desde herdr.dev (cuando haya build Windows)
# curl -fsSL https://herdr.dev/install.ps1 | powershell
```

Verificar:
```bat
herdr --version
where herdr
```

### 8.2 Setup primera vez (equivalente a manualherdrsh.md)

**1. Crear archivo global:**
```bat
:: Crear %USERPROFILE%\herdrglobal con TABs reales
:: Usar Notepad++ o VS Code con "Render Whitespace" para asegurar TAB
notepad %USERPROFILE%\herdrglobal
```
Contenido ejemplo (TAB entre label y comando):
```
opencode	opencode
pi	pi
git	lazygit
glow	glow
tonyscode	tonyscode
```

**2. Configurar variable de entorno:**
```bat
:: Persistente (requiere reiniciar terminal)
setx HERDR_GLOBAL_FILE "%USERPROFILE%\herdrglobal"

:: Solo sesión actual
set HERDR_GLOBAL_FILE=C:\Users\TuUsuario\herdrglobal
```
Verificar:
```bat
echo %HERDR_GLOBAL_FILE%
```

**3. Instalar jq:**
```bat
winget install jqlang.jq
:: o
choco install jq
```

**4. Uso diario:**
```bat
C:\Tony\mi-proyecto> herdr.bat
```

### 8.3 herdr.tabs por proyecto

Mismo formato TSV, ubicado junto a `herdr.bat`:
```
dev	npm run dev
logs	docker compose logs -f
```

- Opcional, si no existe → solo tabs globales.
- Se recomienda commitearlo (infra del proyecto).
- No deduplicación (igual que Linux).

---

## 9. Decisiones Abiertas y Trade-offs

| # | Pregunta | Opciones | Recomendación |
|---|---|---|---|
| 1 | ¿Batch puro o con PowerShell helper? | A) 100% batch (frágil) B) batch + PowerShell para TSV/JSON | **B** — robusto, PowerShell está en todo Windows |
| 2 | ¿Shell del pane raíz? | `cmd.exe` / `powershell.exe` / `bash` | **`cmd.exe` default**, documentar override vía TSV |
| 3 | ¿Dependencia jq? | Requerir jq / usar PowerShell ConvertFrom-Json | **Requerir jq v1**, PowerShell como fallback v1.1 |
| 4 | ¿Soportar `herdr.ps1` además? | Solo `.bat` / ambos | **Solo `.bat` en v1**, `.ps1` como backlog |
| 5 | ¿`herdr.bat` en cada repo o en PATH? | Copia por repo (como `herdr.sh` hoy) / bin global | **Copia por repo** para paridad, más `%PATH%` opcional |
| 6 | ¿Encoding del .bat? | ANSI / UTF-8 con BOM / UTF-8 sin BOM | **UTF-8 sin BOM + `chcp 65001`** si hay acentos |

---

## 10. Criterios de Aceptación

- [ ] `herdr.bat` sin `herdr.tabs` produce mismos tabs que `herdr.sh` con mismo `herdrglobal`.
- [ ] `herdr.bat` con `herdr.tabs` agrega tabs locales DESPUÉS de globales, en orden.
- [ ] Ausencia de `%HERDR_GLOBAL_FILE%` usa `%USERPROFILE%\herdrglobal` con warning en stderr.
- [ ] Ausencia de archivo global genera warning pero no falla (continúa).
- [ ] Líneas malformadas (sin TAB) se skipean con `warning: <file>:<n>: linea malformada` y no abortan.
- [ ] Comentarios (`#`) y líneas vacías se ignoran.
- [ ] Toggle-off funciona: workspace con >1 tab se cierra y sale con `Workspace '<label>' (id=...) cerrado.`
- [ ] Populate funciona: workspace con 1 tab renombra a `terminal` y puebla sin crear workspace nuevo.
- [ ] Create funciona: workspace inexistente se crea con `herdr workspace create --cwd` y tab raíz `terminal`.
- [ ] `herdr workspace focus` se ejecuta al final de create/populate.
- [ ] `where jq` y `where herdr` validados con mensaje de error accionable si faltan.
- [ ] Label = basename del dir que contiene `herdr.bat` (no hardcodeado).
- [ ] `herdr.bat --help` o `herdr.bat /?` opcional muestra uso (nice-to-have).

---

## 11. Plan de Testing

### 11.1 Tests manuales (Windows 10/11)

```bat
:: Test 1: sin workspace → crea
rmdir /s /q %TEMP%\herdr-test && mkdir %TEMP%\herdr-test
copy herdr.bat %TEMP%\herdr-test\
echo opencode	opencode> %USERPROFILE%\herdrglobal
pushd %TEMP%\herdr-test && herdr.bat && popd
:: verificar: herdr workspace list | jq

:: Test 2: toggle off (segunda ejecución)
pushd %TEMP%\herdr-test && herdr.bat && popd
:: debe cerrar

:: Test 3: con herdr.tabs local
echo dev	npm run dev> %TEMP%\herdr-test\herdr.tabs
pushd %TEMP%\herdr-test && herdr.bat && popd
:: verificar orden: terminal, opencode, dev

:: Test 4: línea malformada
echo malformada sin tab>> %USERPROFILE%\herdrglobal
pushd %TEMP%\herdr-test && herdr.bat 2>&1 | findstr "malformada"
```

### 11.2 Tests automatizados (opcional)

- Pester (PowerShell) o `bats` vía Git Bash para CI.
- Mock de `herdr` CLI con script que devuelve JSON fixture.

---

## 12. Riesgos y Mitigaciones

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Parsing TAB en batch puro es frágil | Tabs no se crean, warnings falsos | Usar helper PowerShell para TSV (decisión §7.2) |
| `jq` no instalado | Script falla silencioso | Validación `where jq` con mensaje `winget install` |
| `herdr.exe` no en PATH | `herdr` no encontrado | Validación `where herdr` + doc instalación Windows |
| Paths con espacios (`C:\Users\Nombre Apellido\...`) | `herdr workspace create --cwd` falla | Siempre quotear: `"%PROYECTO_DIR%"`, `"%GLOBAL_TABS_FILE%"` |
| CRLF vs LF | `for /f` puede dejar `\r` en label | Trim `\r` en PowerShell helper o `set "LABEL=%LABEL:\r=%"` |
| Diferencia `cmd.exe` vs `bash` | Comandos Linux no corren en Windows | Documentar: comandos en TSV deben ser Windows-compatibles o usar `wsl` prefix |

---

## 13. Entregables

| Archivo | Rol | Versionado |
|---|---|---|
| `herdr.bat` | Script principal Windows | En cada repo (copia, como `herdr.sh`) |
| `%USERPROFILE%\herdrglobal` | Tabs globales | Dotfiles del usuario |
| `herdr.tabs` (opcional) | Tabs locales por proyecto | Commiteado en repo |
| `PRD_herdrbat.md` (este archivo) | PRD del port | En repo `herdr` |
| `manualherdrbat.md` (futuro) | Manual Windows equivalente a `manualherdrsh.md` | En repo `herdr` |

---

## 14. Roadmap Futuro

- **v1.0 (este PRD):** `herdr.bat` con `jq` + helper PowerShell para TSV, paridad 1:1.
- **v1.1:** Fallback sin `jq` (PowerShell `ConvertFrom-Json`), `chcp 65001` automático.
- **v1.2:** `herdr.ps1` nativo PowerShell (mejor UX, sin batch quirks, soporte `pwsh`).
- **v2.0:** Instalador Windows (`install.ps1` / `winget`) que configure `HERDR_GLOBAL_FILE` y `herdrglobal` automáticamente.

---

## 15. Referencias

- `herdr.sh` v2.0.0 — `C:\Tony\herdr\herdr.sh`
- `manualherdrsh.md` — comportamiento toggle y formato TSV
- `20260814_prd_herdr_global.md` — PRD original global+local tabs
- `README.md` — instalación Unix (base para doc Windows)
- HERDR docs: `https://herdr.dev`

---

## Apéndice A: Ejemplo completo `herdr.bat` (esqueleto funcional)

> Este esqueleto es ilustrativo para el implementador. La versión final debe testearse en Windows real.

```bat
@echo off
setlocal EnableExtensions EnableDelayedExpansion
:: herdr.bat — toggle workspace (Windows port of herdr.sh)
:: Version: 2.0.0
:: Last modified: 2026-09-05
:: Tab sources (in order):
::   1. Global: %HERDR_GLOBAL_FILE% or %USERPROFILE%\herdrglobal  (TSV: label<TAB>command)
::   2. Local:  herdr.tabs in the project dir                      (same TSV format, optional)

for /f "tokens=3" %%v in ('findstr /b ":: Version:" "%~f0"') do set "VERSION=%%v"
echo herdr v%VERSION%

set "PROYECTO_DIR=%~dp0"
if "%PROYECTO_DIR:~-1%"=="\" set "PROYECTO_DIR=%PROYECTO_DIR:~0,-1%"
for %%I in ("%PROYECTO_DIR%") do set "LABEL=%%~nxI"

if defined HERDR_GLOBAL_FILE (
  set "GLOBAL_TABS_FILE=%HERDR_GLOBAL_FILE%"
  echo HERDR_GLOBAL_FILE=%HERDR_GLOBAL_FILE%
) else (
  set "GLOBAL_TABS_FILE=%USERPROFILE%\herdrglobal"
  1>&2 echo herdr: warning: HERDR_GLOBAL_FILE no esta definida, usando default: %GLOBAL_TABS_FILE%
  1>&2 echo herdr: tip: ejecuta 'setx HERDR_GLOBAL_FILE "C:\ruta\al\archivo"' y reinicia la terminal
)

set "LOCAL_TABS_FILE=%PROYECTO_DIR%\herdr.tabs"

where herdr >nul 2>nul || (1>&2 echo herdr: error: herdr no encontrado en PATH & exit /b 1)
where jq >nul 2>nul || (1>&2 echo herdr: error: jq no encontrado. Instala con 'winget install jqlang.jq' & exit /b 1)

:: Buscar workspace por label
for /f "delims=" %%I in ('herdr workspace list ^| jq -r --arg label "%LABEL%" "[.result.workspaces[] | select(.label == $label)] | first // empty | @base64"') do set "WS_B64=%%I"

:: ... (decodificar, branch toggle-off/populate/create, crear tabs via :LOAD_TABS) ...

:: Ejemplo carga tabs globales
if exist "%GLOBAL_TABS_FILE%" (
  call :LOAD_TABS_FROM_FILE "%GLOBAL_TABS_FILE%"
) else (
  1>&2 echo herdr: warning: archivo global no encontrado: %GLOBAL_TABS_FILE%
)

if exist "%LOCAL_TABS_FILE%" (
  call :LOAD_TABS_FROM_FILE "%LOCAL_TABS_FILE%"
)

echo Workspace '%LABEL%' creado. id=%WS_ID%
herdr workspace focus %WS_ID%
exit /b 0

:LOAD_TABS_FROM_FILE
:: Implementado via PowerShell helper para robustez TAB/UTF-8
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$f='%~1'; $ws=$env:WS_ID; $n=0; Get-Content -LiteralPath $f | ForEach-Object { $n++; $l=$_; if($l -match '^\s*#' -or $l -match '^\s*$'){return} if($l -notmatch \"`t\"){ Write-Host \"herdr: warning: ${f}:$n: linea malformada (sin TAB), se ignora: '$l'\" -ForegroundColor Yellow; return } $a=$l.Split(\"`t\",2); $label=$a[0]; $cmd=$a[1]; $j=herdr tab create --workspace $ws --label $label --no-focus | ConvertFrom-Json; $pane=$j.result.root_pane.pane_id; herdr pane run $pane $cmd }"
exit /b 0
```

---

## Apéndice B: Diferencias clave Batch vs Bash a validar

| Bash (`herdr.sh`) | Batch (`herdr.bat`) | Nota |
|---|---|---|
| `set -euo pipefail` | `setlocal EnableExtensions` + `if errorlevel 1` | Batch no tiene pipefail nativo |
| `grep '^# Version:'` | `findstr /b ":: Version:"` | Sintaxis distinta |
| `jq -r '.workspace_id'` | `jq -r ".workspace_id"` | Quoting Windows |
| `herdr pane run "$PANE" "bash"` | `herdr pane run %PANE% "cmd.exe"` | Shell default Windows |
| `echo ... >&2` | `1>&2 echo ...` | Redirección stderr batch |
| `${HOME}/herdrglobal` | `%USERPROFILE%\herdrglobal` | Env var Windows |
| `exit 0` | `exit /b 0` | Sin `/b` cierra la terminal |

