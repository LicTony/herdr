# herdr.sh — Explicación del código (Linux/bash)

`herdr.sh` es la versión original (bash) del toggle de workspace: si el workspace del proyecto ya existe y está "completo", lo cierra; si no existe, lo crea y lo puebla con tabs.

Ver también: [herdr.bat.md](herdr.bat.md) para la versión Windows del mismo script (más compleja, porque tiene que resolver a mano varias cosas que acá vienen gratis del shell).

---

## 1. Cabecera y modo estricto (líneas 1–13)

```bash
set -euo pipefail
```

- `-e`: corta el script ante cualquier comando que falle (exit code ≠ 0).
- `-u`: error si se usa una variable no definida.
- `-o pipefail`: un pipe (`a | b`) falla si **cualquiera** de sus componentes falla, no solo el último.

Esto es la razón por la que el script es mucho más corto que `herdr.bat`: no necesita chequear `errorlevel` a mano después de cada comando — si algo falla, el script entero muere ahí, con el mensaje de error real del comando que falló.

```bash
VERSION=$(grep '^# Version:' "${BASH_SOURCE[0]}" | awk '{print $3}')
```

Extrae la versión de su propio comentario de cabecera (línea 4), igual patrón que en el `.bat`.

## 2. Directorio de proyecto y label (líneas 15–16)

```bash
PROYECTO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABEL="$(basename "$PROYECTO_DIR")"
```

`dirname` + `cd` + `pwd` resuelve symlinks y da siempre una ruta absoluta canónica, sin importar desde dónde se invoque el script. `LABEL` es simplemente el nombre de esa carpeta.

## 3. Archivos TSV global y local (líneas 18–27)

```bash
GLOBAL_TABS_FILE="${HERDR_GLOBAL_FILE:-${HOME}/herdrglobal}"
LOCAL_TABS_FILE="${PROYECTO_DIR}/herdr.tabs"

if [[ -v HERDR_GLOBAL_FILE ]]; then
  echo "HERDR_GLOBAL_FILE=${HERDR_GLOBAL_FILE}"
else
  echo "herdr: warning: ..." >&2
fi
```

`${VAR:-default}` da el valor default sin marcar la variable como "definida" — por eso el chequeo real de si el usuario configuró la env var se hace aparte con `[[ -v HERDR_GLOBAL_FILE ]]`, para poder mostrar el warning solo cuando corresponde.

## 4. Buscar workspace existente por label (líneas 29–35)

```bash
WS_INFO=$(herdr workspace list | jq -r --arg label "$LABEL" \
  '[.result.workspaces[] | select(.label == $label)] | first // empty')
```

Acá sí se puede pipear `herdr workspace list` directo a `jq` (a diferencia del `.bat`, que necesita un archivo temporal por problemas de quoting). El filtro `select(.label == $label) | first // empty` devuelve el primer workspace cuyo label coincide, o vacío si no hay ninguno.

## 5. Lógica de toggle (líneas 33–60)

Tres caminos:

1. **`TAB_COUNT > 1`**: el workspace ya tiene los tabs auxiliares (está "completo") → se interpreta como que el usuario lo quiere cerrar. `herdr workspace close "$WS_ID"` y `exit 0`.
2. **`TAB_COUNT == 1`**: existe pero solo tiene el tab raíz (el que crea `workspace create` automáticamente) → hay que poblarlo. Busca el `tab_id` raíz con `tab list`, el `pane_id` de ese tab con `pane list | jq ... | head -1` (se queda con el primer pane que matchea ese tab), lo renombra a `"terminal"` y corre `bash` adentro.
3. **No existe ningún workspace con ese label** → `workspace create --cwd "$PROYECTO_DIR" --label "$LABEL"`, extrae `pane_id`, `workspace_id` y `tab_id` de la respuesta JSON en una sola pasada (tres `jq` distintos sobre el mismo `$WS_JSON`), renombra el tab y corre `bash`.

Notar que **no hay auto-arranque del daemon** acá: si `herdr workspace list` falla porque no hay ninguna sesión corriendo, el `set -e` corta el script con el error crudo de `herdr`/`jq`. Es una diferencia deliberada de diseño respecto al `.bat` — en Linux se asume que el daemon ya está corriendo (por ejemplo vía un servicio de systemd/autostart, ver `activar_autostart.sh`), en vez de que el propio toggle-script se encargue de levantarlo.

## 6. Tabs auxiliares (líneas 62–108)

### `create_tab()` (línea 64)

```bash
create_tab() {
  local label="$1" cmd="$2"
  tab_json=$(herdr tab create --workspace "$WS_ID" --label "$label" --no-focus)
  pane_id=$(echo "$tab_json" | jq -r '.result.root_pane.pane_id')
  herdr pane run "$pane_id" "$cmd"
}
```

Función simple: crea el tab, extrae el pane raíz, corre el comando ahí. `--no-focus` evita que cada tab nuevo le robe el foco al que se está creando.

### `load_tabs_from_file()` (línea 75)

```bash
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ "$line" =~ ^[[:space:]]*# ]] && continue        # comentario
  [[ -z "${line// }" ]] && continue                   # línea vacía
  if [[ "$line" != *$'\t'* ]]; then                    # sin TAB → warning y skip
    echo "herdr: warning: ...línea malformada..." >&2
    continue
  fi
  label="${line%%$'\t'*}"   # todo antes del primer TAB
  cmd="${line#*$'\t'}"      # todo después del primer TAB
  create_tab "$label" "$cmd"
done < "$file"
```

Parsing de TSV puramente con expansión de parámetros de bash (`${var%%patrón}` / `${var#patrón}`), sin depender de `awk`/`cut` externos. El `|| [[ -n "$line" ]]` en la condición del `while` es el truco estándar para no perder la última línea de un archivo que no termina en newline.

`$'\t'` es la forma bash de escribir un TAB literal dentro de un string — equivalente al `` `t `` de PowerShell o al TAB literal entre comillas que usa la versión batch.

## 7. Armado del mensaje de tabs (líneas 94–108)

```bash
TAB_LABELS="opencode"
if [[ -f "$GLOBAL_TABS_FILE" ]]; then
  load_tabs_from_file "$GLOBAL_TABS_FILE"
  TAB_LABELS+=" | $(grep -v '^[[:space:]]*#' "$GLOBAL_TABS_FILE" | grep $'\t' | awk -F$'\t' '{printf "%s | ", $1}' | sed 's/ | $//')"
fi
```

A diferencia del `.bat` (que separa "crear tabs" y "armar labels" en dos subrutinas distintas que recorren el archivo dos veces), acá se llama `load_tabs_from_file` (crea los tabs) y **en la misma pasada de shell** se arma el string de labels con un pipeline aparte (`grep` + `awk` + `sed`) sobre el mismo archivo — dos recorridos del archivo igual, pero expresados como una sola línea de pipeline en vez de una función separada.

## 8. Cierre (líneas 110–114)

```bash
echo "Workspace '$LABEL' creado. id=$WS_ID"
echo "Tabs: ${TAB_LABELS}"
herdr workspace focus "$WS_ID"
```

Enfoca el workspace recién creado/poblado. No hace falta ningún equivalente a `endlocal` — las variables de un script bash ya son locales a su propio proceso.

---

## Diferencias clave respecto a `herdr.bat`

| Aspecto | `herdr.sh` | `herdr.bat` |
|---|---|---|
| Manejo de errores | `set -euo pipefail` corta ante el primer fallo | Chequeos manuales de `errorlevel` después de cada comando |
| Auto-arranque del daemon | No — asume sesión ya corriendo | Sí, con detección de ventana visible y polling |
| Pipe directo a `jq` | Sí (`herdr ... | jq ...`) | No — usa archivos temporales por problemas de quoting en batch |
| Parsing de TSV | Expansión de parámetros bash nativa | PowerShell (robusto) o batch puro (fallback) |
| Shell que corre en el pane | `bash` | `pwsh.exe -NoLogo` |
