# herdr.bat — Explicación del código (Windows)

`herdr.bat` es el port a Windows (cmd.exe) de `herdr.sh`. Hace exactamente lo mismo — abrir/poblar/cerrar un workspace de `herdr` para el proyecto actual — pero tiene que resolver a mano varios problemas que en bash vienen gratis: parsing de TSV con TAB real, saber si hay una ventana visible, elegir entre `powershell`/`pwsh`, etc.

Ver también: [herdr.sh.md](herdr.sh.md) para la versión Linux/bash del mismo script.

---

## 1. Cabecera y versión (líneas 1–15)

```bat
@echo off
chcp 65001 >nul 2>&1
setlocal EnableExtensions EnableDelayedExpansion
```

- `chcp 65001` fuerza la consola a UTF-8 (necesario para labels/comandos con acentos o emojis en los TSV).
- `EnableDelayedExpansion` es obligatorio porque el script lee y modifica variables **dentro de bloques `(...)`** (loops `for`, `if`) constantemente. Sin esto, `%VAR%` se expandiría con el valor que tenía *antes* de entrar al bloque, no el actualizado — la fuente número uno de bugs en batch.
- La versión se extrae del propio comentario `:: Version: 2.0.0` del archivo con `findstr` + `for /f "tokens=3"`, así el número solo vive en un lugar (línea 5).

## 2. Directorio de proyecto y label (líneas 17–20)

```bat
set "PROYECTO_DIR=%~dp0"
if "!PROYECTO_DIR:~-1!"=="\" set "PROYECTO_DIR=!PROYECTO_DIR:~0,-1!"
for %%I in ("!PROYECTO_DIR!") do set "LABEL=%%~nxI"
```

`%~dp0` da la carpeta donde vive `herdr.bat`, con `\` final — se lo recorta, y el `LABEL` del workspace es el nombre de esa carpeta (`%%~nxI` = nombre + extensión del último componente del path). Equivalente exacto a `basename "$PROYECTO_DIR"` en el `.sh`.

## 3. Archivo TSV global y local (líneas 22–31)

Igual que en `herdr.sh`: si `HERDR_GLOBAL_FILE` está definida se usa esa ruta, si no cae a `%USERPROFILE%\herdrglobal` con un warning + tip. El local siempre es `<PROYECTO_DIR>\herdr.tabs`.

## 4. Resolución de `HERDR_BIN` (líneas 33–48)

Esta parte es la más delicada del port y la que más cambió recientemente:

```bat
for /f "delims=" %%I in ('where herdr 2^>nul') do (
  if not defined HERDR_BIN (
    echo %%I | findstr /i ".exe" >nul
    if not errorlevel 1 set "HERDR_BIN=%%I"
  )
)
if not defined HERDR_BIN (
  for /f "delims=" %%I in ('where herdr 2^>nul') do if not defined HERDR_BIN set "HERDR_BIN=%%I"
)
```

`where herdr` puede devolver **varios matches** si `herdr.bat` (este mismo archivo) vive en un directorio que también está en el `PATH` — cosa que pasa en este proyecto, porque `C:\Tony\herdr` está en PATH. Sin este filtro, el script podía terminar apuntando a sí mismo (`HERDR_BIN=herdr.bat`) y entrar en un loop recursivo. Por eso:

1. Primer loop: recorre todos los resultados de `where herdr` y se queda con el **primero que contenga `.exe`**, descartando el `.bat`.
2. Si ningún resultado tiene `.exe` (caso raro, herdr no instalado como exe), el segundo loop cae al primer match sin filtrar, para no dejar `HERDR_BIN` vacío silenciosamente.

Después valida que exista `jq` en PATH (obligatorio, se usa para parsear todo el JSON que devuelve `herdr`) y detecta si hay `powershell`/`pwsh` (`HAS_POWERSHELL`) y `wt.exe` (`HAS_WT`) disponibles, porque el resto del script tiene rutas alternativas según qué herramientas están instaladas.

## 5. Asegurar que exista una sesión de herdr visible (líneas 65–113)

Esta es la lógica que se agregó para que `herdr.bat` funcione "solo": si no hay ningún daemon de herdr corriendo, lo arranca; si está corriendo pero sin ventana visible, abre una.

```bat
"%HERDR_BIN%" status server > "%TEMP%\herdr_status_tmp.json" 2>&1
findstr /i /c:"not running" "%TEMP%\herdr_status_tmp.json" >nul
if not errorlevel 1 ( ... arrancar nueva sesión ... )
```

Se redirige la salida a un archivo temporal en vez de comparar `errorlevel` directo, porque `herdr status server` puede devolver texto distinto según el estado y el script necesita **leer el contenido**, no solo el código de salida.

- **Si no hay sesión corriendo**: si hay Windows Terminal, la abre con `start "" wt.exe new-tab --startingDirectory "!PROYECTO_DIR!" pwsh.exe -NoLogo -Command "& '!HERDR_BIN!'"` (ventana moderna, con ConPTY); si no, hace `start "" "%HERDR_BIN%"` a secas. Después hace polling cada 500ms, hasta 40 intentos (~20s), reconsultando `status server` hasta que deje de decir "not running".
- **Si ya hay sesión pero sin ventana**: usa PowerShell para contar procesos `herdr` con `MainWindowHandle -ne 0` (o sea, con ventana real, no solo el proceso de fondo). Si el conteo es 0, abre una ventana igual que en el caso anterior.

> ⚠️ **Nota de troubleshooting**: si esta sección arranca el daemon desde una terminal **elevada** (ej. `cmd` "Ejecutar como administrador"), el socket IPC de `herdr` (`%APPDATA%\herdr\herdr.sock`) queda con integridad Alta, y cualquier invocación posterior de `herdr.bat` desde una terminal normal falla con `herdr: Acceso denegado. (os error 5)` — Windows Mandatory Integrity Control bloquea el acceso aunque la ACL del archivo lo permita. La solución es matar el daemon y dejar que se reinicie desde un contexto no elevado.

## 6. Buscar workspace existente por label (líneas 115–123)

```bat
"%HERDR_BIN%" workspace list > "!WS_LIST_TMP!" 2>nul
for /f "delims=" %%I in ('jq -r --arg label "!LABEL!" "..." "!WS_LIST_TMP!"') do set "WS_ID=%%I"
```

Se vuelca `workspace list` a un archivo temporal (no se puede pipear directo a `jq` dentro de un `for /f` sin líos de escaping con comillas anidadas) y se filtra con `jq` por `label == $LABEL`. Se usa un archivo en vez de un pipe explícitamente para **evitar el pipe** (`|`) dentro del `for /f`, que en batch tiene problemas de quoting cuando se mezclan comillas simples/dobles con `jq`.

## 7. Lógica de toggle (líneas 125–181)

Tres caminos, igual que en `herdr.sh`:

1. **`TAB_COUNT > 1`** → el workspace ya está "completo" (tiene los tabs auxiliares creados) → se interpreta como toggle-off: `workspace close` y listo (`exit /b 0`).
2. **`TAB_COUNT == 1`** → existe pero es solo el tab raíz vacío → se puebla: busca el `tab_id` raíz con `tab list`, el `pane_id` de ese tab con `pane list` (con fallback al primer pane si el filtro no matchea nada), lo renombra a `"terminal"` y corre `pwsh.exe -NoLogo` adentro.
3. **No existe** → `workspace create --cwd ... --label ...`, parsea `workspace_id`, `tab_id` y `pane_id` de la respuesta JSON, renombra el tab y corre `pwsh.exe -NoLogo`.

Todas las validaciones (`if not defined TAB_ROOT`, etc.) cortan con `exit /b 1` y un mensaje `herdr: error: ...` si `jq` no pudo extraer el campo esperado — la respuesta de `herdr` cambió de forma o el workspace quedó en un estado raro.

## 8. Tabs auxiliares (líneas 184–196, subrutinas 204–272)

```bat
set "TAB_LABELS=opencode"
if exist "!GLOBAL_TABS_FILE!" (
  call :LOAD_TABS_FROM_FILE "!GLOBAL_TABS_FILE!"
  call :APPEND_LABELS "!GLOBAL_TABS_FILE!"
)
if exist "!LOCAL_TABS_FILE!" ( ... igual ... )
```

Dos subrutinas separadas porque **crear** los tabs y **armar el string** para el mensaje final (`Tabs: opencode | git | ...`) son pasos independientes.

### `:LOAD_TABS_FROM_FILE` (línea 208)

Tiene **dos implementaciones** según si hay PowerShell disponible:

- **`:LOAD_TABS_PS`**: un one-liner de PowerShell embebido que lee el archivo con `Get-Content -Encoding utf8`, separa por TAB real (`` `t ``), ignora comentarios/líneas vacías, valida que haya TAB, y por cada línea válida llama `herdr tab create` + `herdr pane run` capturando el pane_id con `ConvertFrom-Json`. Es la vía "robusta" — maneja bien UTF-8, CRLF y TABs sin ambigüedad.
- **`:LOAD_TABS_BATCH`**: fallback puro batch para cuando no hay PowerShell instalado. Usa `for /f "tokens=1,* delims=	"` (el delimitador entre las comillas es un TAB literal) para separar label/comando, valida línea por línea y llama a `:CREATE_TAB` por cada una. Es más frágil que la versión PS (batch tiene límites de longitud de línea y problemas conocidos con caracteres especiales), pero cubre el caso sin PowerShell.

### `:CREATE_TAB` (línea 242)

Crea un tab con `herdr tab create --no-focus`, extrae el `pane_id` con `jq` y corre el comando ahí con `pane run`. Si falla, solo loguea un warning (`herdr: warning: fallo al crear tab '...'`) y sigue — un tab auxiliar roto no debe abortar todo el workspace.

### `:APPEND_LABELS` (línea 262)

Recorre el mismo TSV y arma `TAB_LABELS` concatenando labels con `" | "`, solo para el mensaje final (`echo Tabs: !TAB_LABELS!`). No crea nada, es puramente cosmético.

## 9. Cierre (líneas 198–202)

```bat
echo Workspace '!LABEL!' creado. id=!WS_ID!
echo Tabs: !TAB_LABELS!
"%HERDR_BIN%" workspace focus "!WS_ID!" >nul
endlocal
exit /b 0
```

Enfoca el workspace recién creado/poblado y termina con `endlocal` para no filtrar variables al shell que invocó el `.bat` (si se llamó con `call`).

---

## Diferencias clave respecto a `herdr.sh`

| Aspecto | `herdr.bat` | `herdr.sh` |
|---|---|---|
| Auto-arranque del daemon si no hay sesión | Sí (líneas 65–113) | No — asume que ya hay una sesión corriendo |
| Verificar ventana visible | Sí, vía PowerShell (`MainWindowHandle`) | No aplica (Linux no tiene este problema de la misma forma) |
| Parsing de TSV | PowerShell (robusto) o batch puro (fallback) | Bash nativo (`IFS`, `read`, expansión de parámetros) |
| Resolución del binario | Filtra `.exe` vs `.bat` por el problema de PATH duplicado | No aplica, no hay ambigüedad de extensión en Linux |
| Shell que corre en el pane | `pwsh.exe -NoLogo` | `bash` |
