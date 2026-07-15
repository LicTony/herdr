# Tutorial de uso de Herdr — Gestión de proyectos por carpeta

> Objetivo personal: tener, en la carpeta de cada proyecto, algo que me abra
> automáticamente las ventanas/paneles que necesito (agente + lazygit, por ej.)
> y poder cerrar todo eso con un solo comando cuando termino.
>
> Este documento está pensado para ir **de a poco**: primero entender qué pasa
> "bajo el capó" con comandos manuales, y recién después pasar al método
> declarativo (un archivo de config por proyecto), que es el que más se parece
> a lo que quiero lograr.

---

## Nivel 0 — Repaso rápido de conceptos

Herdr organiza todo en 4 capas, de más grande a más chica:

```
Workspace  (un proyecto)
  └── Tab       (una "vista" dentro del proyecto: agente, logs, git, etc.)
        └── Pane     (una terminal real: acá corre el proceso)
              └── Agent  (si Herdr detecta un agente corriendo en ese pane)
```

Regla de oro: **un workspace por proyecto**. Así el sidebar te muestra de un
vistazo qué proyecto está `blocked` (necesita tu OK), `working`, `done` o
`idle`.

> **Prerrequisito:** instalá `jq` (`sudo apt install jq`, `brew install jq`,
> `choco install jq`, etc. según tu sistema). Es la herramienta estándar para
> parsear JSON en scripts de shell, y la vamos a usar desde el Nivel 2 en vez
> de tirar de Python solo para leer un campo de un JSON.

---

## Nivel 1 — Abrir un proyecto a mano (lo que ya sabemos)

Esto ya lo vimos: entrás a la carpeta, corrés `herdr`, y adentro creás tabs y
panes con el mouse o con `prefix+v` (split derecha), `prefix+c` (nuevo tab),
etc. Corrés `opencode`, `pi` o el CLI de `antigravity` en un pane, y `lazygit`
en otro.

Esto funciona, pero tiene un costo: **lo tenés que rehacer cada vez** que
abrís ese proyecto. Ahí es donde entra la automatización.

---

## Nivel 2 — Automatizar la apertura con un script (comandos CLI)

Herdr tiene un CLI que le habla al servidor que ya está corriendo. Los
comandos más importantes para armar un layout son:

- `herdr workspace create` → crea el proyecto (workspace) y su primer tab/pane.
- `herdr tab create` → agrega un tab nuevo dentro de ese workspace.
- `herdr pane split` → divide un pane existente (derecha o abajo).
- `herdr pane run` → le manda un comando a un pane para que lo ejecute.

**Importante:** casi todos estos comandos devuelven un JSON con el `id` de lo
que acaban de crear (workspace, tab, pane). Ese id lo necesitás para el
siguiente paso, porque los ids no son fijos: si cerrás cosas, Herdr los
reordena. Por eso en un script siempre "encadenamos" leyendo el id de la
respuesta anterior, en vez de escribirlo a mano.

### Ejemplo: script para levantar "proyecto-A"

Este script hace 4 cosas, en orden:
1. Crea el workspace con el nombre del proyecto, en la carpeta correcta.
2. En el pane inicial de ese workspace, arranca tu agente (`opencode` en este
   ejemplo — cambialo por `pi` o el comando de `antigravity` según el
   proyecto).
3. Crea un tab nuevo llamado "git".
4. En ese tab, corre `lazygit`.

```bash
#!/usr/bin/env bash
# herdr-start.sh — va guardado en la carpeta del proyecto
set -euo pipefail

PROYECTO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABEL="$(basename "$PROYECTO_DIR")"   # auto-detecta el nombre del proyecto

# 1) Crear el workspace y capturar el id del pane raíz
WS_JSON=$(herdr workspace create --cwd "$PROYECTO_DIR" --label "$LABEL")
PANE_AGENTE=$(echo "$WS_JSON" | jq -r '.result.root_pane.pane_id')
WS_ID=$(echo "$WS_JSON" | jq -r '.result.workspace.id')

# 2) Arrancar el agente en ese pane
herdr pane run "$PANE_AGENTE" "opencode"

# 3) Crear un tab nuevo para git, dentro del mismo workspace
TAB_JSON=$(herdr tab create --workspace "$WS_ID" --label "git" --no-focus)
PANE_GIT=$(echo "$TAB_JSON" | jq -r '.result.root_pane.pane_id')

# 4) Correr lazygit en ese pane
herdr pane run "$PANE_GIT" "lazygit"

echo "Workspace '$LABEL' listo. id=$WS_ID"
```

**Por qué está armado así:**
- Usamos `jq` para extraer el id del JSON en vez de "adivinarlo" a ojo,
  porque Herdr avisa explícitamente que los ids se pueden reordenar cuando
  se cierran cosas — no son estables entre sesiones. `jq` es más legible que
  `python3 -c` y es la herramienta estándar para esto en cualquier script de
  shell moderno.
- `LABEL` se calcula con `basename` en vez de escribirlo a mano: si copiás
  este script a otro proyecto, no hay que acordarse de cambiar esa línea.
- `--no-focus` en el tab de git evita que te salte el foco ahí y te saque del
  agente que recién arrancaste.
- Guardamos el `WS_ID` al final porque lo vamos a necesitar para **cerrar**
  todo el proyecto de una sola vez (nivel 3).

Para usarlo: guardás este archivo como `herdr-start.sh` adentro de la carpeta
del proyecto, le das permiso de ejecución una vez (`chmod +x herdr-start.sh`)
y lo corrés con `./herdr-start.sh`.

---

## Nivel 3 — Cerrar todo con un solo comando

Existe el comando:

```bash
herdr workspace close --workspace <ID>
```

Esto cierra el workspace completo (todos sus tabs y panes) **solo a nivel
Herdr** — no borra tu código ni tu repo, simplemente termina esos procesos y
saca el proyecto del sidebar.

El problema práctico es conseguir el `<ID>` cuando no lo tenés a mano (por
ejemplo, si cerraste la terminal y volviste otro día). Para eso:

```bash
herdr workspace list
```

Esto te lista todos los workspaces activos con su id y label. Buscás el que
tenga el label de tu proyecto (ej. `proyecto-A`) y usás ese id.

### Script de cierre, buscando por nombre

Para no tener que copiar el id a mano cada vez, este script busca el
workspace por su label y lo cierra:

```bash
#!/usr/bin/env bash
# herdr-stop.sh — cierra el workspace de este proyecto por su label
set -euo pipefail
LABEL="$(basename "$(pwd)")"   # mismo criterio que herdr-start.sh

WS_ID=$(herdr workspace list | jq -r --arg label "$LABEL" \
  '.result.workspaces[] | select(.label == $label) | .id')

if [ -z "$WS_ID" ]; then
  echo "No encontré un workspace con label '$LABEL'"
  exit 1
fi

herdr workspace close --workspace "$WS_ID"
echo "Workspace '$LABEL' (id=$WS_ID) cerrado."
```

Con esto ya tenés el ciclo completo **abrir con un comando / cerrar con
otro**, sin tocar el mouse.

### Unificando todo en un solo script (`herdr-project.sh`)

Tener `herdr-start.sh` y `herdr-stop.sh` como dos archivos separados funciona,
pero repite el cálculo del `LABEL` y hace que cada proyecto tenga que copiar
dos archivos en vez de uno. Es más prolijo unificarlos en un solo script
ejecutable con subcomandos, al estilo `git <subcomando>`:

```bash
#!/usr/bin/env bash
# herdr-project.sh — start | stop | status para el proyecto de esta carpeta
set -euo pipefail

PROYECTO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABEL="$(basename "$PROYECTO_DIR")"

cmd_start() {
  WS_JSON=$(herdr workspace create --cwd "$PROYECTO_DIR" --label "$LABEL")
  PANE_AGENTE=$(echo "$WS_JSON" | jq -r '.result.root_pane.pane_id')
  WS_ID=$(echo "$WS_JSON" | jq -r '.result.workspace.id')

  herdr pane run "$PANE_AGENTE" "opencode"

  TAB_JSON=$(herdr tab create --workspace "$WS_ID" --label "git" --no-focus)
  PANE_GIT=$(echo "$TAB_JSON" | jq -r '.result.root_pane.pane_id')
  herdr pane run "$PANE_GIT" "lazygit"

  echo "Workspace '$LABEL' listo. id=$WS_ID"
}

cmd_stop() {
  local ws_id
  ws_id=$(herdr workspace list | jq -r --arg label "$LABEL" \
    '.result.workspaces[] | select(.label == $label) | .id')

  if [ -z "$ws_id" ]; then
    echo "No encontré un workspace con label '$LABEL'"
    exit 1
  fi

  herdr workspace close --workspace "$ws_id"
  echo "Workspace '$LABEL' (id=$ws_id) cerrado."
}

cmd_status() {
  herdr workspace list | jq -r --arg label "$LABEL" \
    '.result.workspaces[] | select(.label == $label)'
}

case "${1:-}" in
  start)  cmd_start ;;
  stop)   cmd_stop ;;
  status) cmd_status ;;
  *)
    echo "Uso: $0 {start|stop|status}"
    exit 1
    ;;
esac
```

Uso:

```bash
chmod +x herdr-project.sh   # una sola vez
./herdr-project.sh start
./herdr-project.sh status
./herdr-project.sh stop
```

**Ventajas de unificarlo:** un solo archivo para copiar a cada proyecto, el
`LABEL` se calcula una sola vez y los tres subcomandos lo comparten, y sumar
un subcomando nuevo (`status`, en este caso) sale gratis porque ya tenés el
esqueleto de `case` armado.

**Desventaja real:** el archivo es un poco más largo y agrega una capa de
"parseo de argumentos" (`case "${1:-}"`) que no existía cuando eran dos
scripts sueltos — si estás recién arrancando con bash, puede ser un poco más
para digerir de una sola vez. Si preferis ir despacio, no hay drama en
quedarte con los dos scripts separados de los Niveles 2 y 3, y unificar más
adelante cuando te resulte cómodo.

---

## Nivel 4 — El siguiente paso: un archivo YAML por proyecto (`herdr-spreader`)

Los scripts de bash del Nivel 2 y 3 funcionan, pero tienen dos problemas:
mantenerlos a mano por cada proyecto es repetitivo, y si el layout crece
(más paneles, variables de entorno, comandos que esperan a que otro termine)
el bash se vuelve difícil de leer.

Para esto existe un **plugin de la comunidad** llamado `herdr-spreader`, que
hace exactamente lo que pediste: **un archivo de configuración (YAML) por
proyecto que define todo el layout — workspace, tabs, panes y comandos — y
Herdr lo arma solo.**

### Instalación (una sola vez)

```bash
herdr plugin install yuk1ty/herdr-spreader
```

### Estructura del archivo (conceptual)

Un archivo de layout tiene 4 niveles, que calzan exactamente con el modelo de
Herdr: el archivo en sí (puede describir más de un workspace), workspaces,
tabs y panes.

Antes de ver el YAML, así queda el layout que vamos a describir (un tab con
el agente + un pane de logs al lado, y un segundo tab para git):

```
┌─ Tab: agente ────────────────────────┬──────────────┐
│                                 │              │
│   opencode (focus)              │  logs (tail) │
│                                 │              │
├────────────────────────────────┴──────────────┤
│ Tab: git                                        │
│   lazygit                                       │
└───────────────────────────────────────────────┘
```

```yaml
workspaces:
  - label: proyecto-A
    cwd: ~/Projects/proyecto-A
    env:                        # variables de entorno para todo el workspace
      NODE_ENV: development
    tabs:
      - label: agente
        panes:
          - cwd: .              # relativo al cwd del workspace
            command: opencode
            focus: true          # este pane queda enfocado al terminar
          - cwd: .
            split: right         # se abre a la derecha del pane anterior
            command: tail -f logs/dev.log
      - label: git
        panes:
          - cwd: .
            command: lazygit
            close_on_exit: false # si el plugin lo soporta: no cierra el pane
                                  # solo porque lazygit termine (por si salís
                                  # sin querer con "q")
```

**Qué significa cada parte:**
- `workspaces` es una lista → podés describir varios proyectos en el mismo
  archivo, o tener un archivo por proyecto (lo que vos querés).
- `cwd` se puede definir a nivel workspace, tab o pane; se van "pisando" de
  arriba hacia abajo (si no ponés uno en el pane, hereda el del tab, que
  hereda el del workspace). Usar `.` explícitamente en el pane es una forma
  clara de decir "el mismo `cwd` del tab", útil para que el archivo se
  entienda sin tener que recordar de memoria la regla de herencia.
- `env` a nivel workspace aplica a todos los panes que arranca ese layout —
  cómodo para variables que necesita el agente (por ejemplo, el modelo a
  usar) sin tener que exportarlas pane por pane.
- `split: right` (o `down`) agrega un segundo pane **dentro del mismo tab**,
  en vez de crear un tab nuevo — útil para tener, por ejemplo, un `tail -f`
  de logs al lado del agente sin tener que cambiar de pestaña.
- `focus: true` marca qué pane queda con el foco cuando termina de armarse
  todo el layout — importante cuando tenés varios paneles y no querés que te
  quede el cursor en `lazygit` en vez de en el agente.
- `close_on_exit` (si tu versión del plugin lo soporta — revisá el `--help`
  o el README del plugin instalado) controla si el pane se cierra solo
  cuando el comando termina. Ponerlo en `false` en el pane de `lazygit`
  evita perder el pane si salís sin querer con `q`.

### Cómo se usa

```bash
# Ejecutarlo apuntando a un archivo específico del proyecto
herdr-spreader --config ./herdr-layout.yaml

# O invocarlo desde el menú de plugins dentro de Herdr
```

Esto es exactamente tu objetivo original: **guardás `herdr-layout.yaml` en la
carpeta de cada proyecto**, y con un solo comando (o un action del plugin) se
te abre todo el layout de ese proyecto.

Para cerrar, por ahora seguís usando `herdr workspace close` (el plugin arma
layouts, no gestiona el cierre) — así que el script del Nivel 3 sigue siendo
útil incluso cuando migres a YAML.

---

## Nivel 4-bis — La alternativa: `herdr-plus` (cloudmanic)

Existe otro plugin real, más completo en features, llamado `herdr-plus`. Vale
la pena conocerlo porque resuelve el mismo problema con un enfoque distinto —
y tiene un matiz importante que afecta directamente tu objetivo de "un
archivo por proyecto, en la carpeta del proyecto".

### Instalación

```bash
herdr plugin install cloudmanic/herdr-plus
```

### Qué trae de más respecto a `herdr-spreader`

- **Projects**: plantillas de workspace, pero en **TOML** (no YAML), elegidas
  desde un buscador fuzzy con una sola tecla — no hace falta acordarse el
  nombre del archivo ni escribir el comando a mano.
- **Hasta 4 panes por tab**, con `[[tabs.panes]]` y `split = "down" | "right"`.
- **Agrupar proyectos** (`group = "..."`) para ordenarlos en el buscador, por
  ejemplo si tenés varios proyectos del mismo cliente.
- **Quick Actions**: un lanzador fuzzy de comandos sueltos, reutilizable en
  cualquier repo (por ejemplo, "abrir el repo en el navegador" o "correr los
  tests"), separado de los layouts de workspace.
- **Worktree auto-layout**: si trabajás con `git worktree`, apenas Herdr crea
  o abre un worktree nuevo, `herdr-plus` detecta el repo y arma el layout
  automáticamente, sin apretar nada.

### Ejemplo de plantilla (TOML)

```toml
name = "Proyecto A"
description = "El repo principal del cliente X"
working_dir = "~/Projects/proyecto-A"

[[tabs]]
name = "agente"
command = "opencode"

[[tabs]]
name = "git"
command = "lazygit"

[[tabs]]
name = "terminal"   # sin command = una shell vacía
```

Se ve muy parecido al YAML de `herdr-spreader`, ¿no? La diferencia real no
está en la sintaxis, sino en **dónde vive el archivo**.

### ⚠️ El matiz que te afecta directamente

Esto es importante para no llevarte una sorpresa:

- Las plantillas de **Projects** de `herdr-plus` viven **centralizadas** en
  `~/.config/herdr/plugins/config/cloudmanic.herdr-plus/projects/*.toml` — el
  archivo apunta a tu proyecto vía `working_dir`, pero **no vive dentro de la
  carpeta del proyecto**. Es un directorio central con un archivo por
  proyecto, no "un archivo en cada carpeta".
- La única excepción es `.herdr-plus/quick-actions/`, que sí podés poner
  **dentro del repo** — pero eso es solo para accesos rápidos sueltos, no
  para el layout completo de tabs/paneles.
- `herdr-spreader`, en cambio, se invoca con `--config <ruta>`, así que **vos
  elegís dónde vive ese archivo** — lo podés dejar literalmente adentro de la
  carpeta del proyecto, que es justo tu idea original.

### ¿Cuál conviene entonces?

| Si priorizás... | Conviene... |
|---|---|
| Que el archivo de layout viva físicamente en la carpeta del proyecto (tu idea original) | `herdr-spreader` |
| Un buscador fuzzy centralizado + accesos rápidos + auto-layout en worktrees | `herdr-plus` |
| Simplicidad y menos partes móviles para arrancar | `herdr-spreader` (YAML más simple, un solo propósito) |
| Crecer hacia workflows más avanzados con git worktrees | `herdr-plus` |

No son excluyentes: se pueden instalar los dos y probar cuál se siente mejor
en la práctica antes de decidir. Ninguno de los dos gestiona el **cierre** del
workspace — para eso seguís usando `herdr workspace close` (Nivel 3) en
ambos casos.

---

## Nivel 5 — Un `justfile` para no tener que acordarte de comandos

Ya sea que uses el script de bash (Nivel 2/3), `herdr-spreader` (Nivel 4) o
`herdr-plus` (Nivel 4-bis), en algún momento vas a tener comandos distintos
por proyecto (`./herdr-project.sh start`, `herdr-spreader --config
./herdr-layout.yaml`, etc.) y cuesta acordarse cuál es cuál en cada repo.

[just](https://github.com/casey/just) es un "ejecutor de tareas" (parecido a
`make`, pero sin las rarezas de Makefile) que resuelve justo eso: un archivo
llamado `justfile` en la raíz del proyecto, con recetas cortas que siempre se
invocan igual (`just dev`, `just stop`, `just status`) sin importar qué
herramienta uses por debajo.

### Instalación (una sola vez)

```bash
# Linux (apt)
sudo apt install just

# macOS
brew install just

# Windows (con choco o scoop)
choco install just
```

### Ejemplo de `justfile` (usando el script unificado del Nivel 3)

```just
# Lista las recetas disponibles (comando por defecto)
default:
    just --list

# Levanta el workspace completo del proyecto
dev:
    ./herdr-project.sh start

# Cierra el workspace de este proyecto
stop:
    ./herdr-project.sh stop

# Muestra el estado del workspace de este proyecto
status:
    ./herdr-project.sh status
```

Si en cambio estás usando `herdr-spreader` (Nivel 4), la receta `dev` sería
`herdr-spreader --config ./herdr-layout.yaml`, y `stop`/`status` pueden seguir
llamando al script unificado del Nivel 3 (los dos enfoques conviven sin
problema, `just` solo les pone un nombre consistente encima).

**Por qué conviene:**
- No importa qué herramienta uses por debajo — de afuera siempre corrés
  `just dev` / `just stop` / `just status`, y eso es lo que tu memoria
  muscular necesita recordar en todos tus proyectos.
- `just --list` (o simplemente `just`, que corre la receta `default`) te
  recuerda qué recetas hay sin tener que abrir el archivo.
- Es opcional: no reemplaza a Herdr ni a sus plugins, solo les agrega una
  capa de nombres consistentes encima.

---

## Plan de aprendizaje sugerido (para ir de a poco)

- [ ] **Semana 1** — Usar Herdr a mano (Nivel 1) en un solo proyecto real,
  hasta sentirte cómodo con mouse + `prefix+v` / `prefix+c` / `prefix+q`.
- [ ] **Semana 2** — Escribir tu primer `herdr-start.sh` (Nivel 2) para tu
  proyecto más usado. Ejecutarlo y confirmar que abre lo que esperás.
- [ ] **Semana 3** — Agregar el `herdr-stop.sh` (Nivel 3) y probar el ciclo
  completo abrir → trabajar → cerrar, un par de días.
- [ ] **Semana 4** — Instalar `herdr-spreader` y migrar ese mismo proyecto a
  un archivo YAML. Comparar contra el script de bash.
- [ ] **Semana 5** — Instalar `herdr-plus` en paralelo y probar sus Projects
  + Quick Actions con el mismo proyecto, para comparar en la práctica contra
  `herdr-spreader` antes de elegir uno de los dos como definitivo.
- [ ] **Semana 6** — Instalar `just` y armar un `justfile` con las recetas
  `dev` / `stop` / `status` (Nivel 5), para no tener que acordarte del
  comando exacto de la herramienta que elegiste en las semanas 4 y 5.
- [ ] **Después** — Replicar la solución elegida para cada uno de tus otros
  proyectos (los que usan `pi`, `antigravity`, etc.), ajustando el comando
  de cada pane.

---

## Troubleshooting — problemas comunes

- **El script falla apenas arranca, con un error de `jq` tipo "Cannot index
  string with string"**: normalmente significa que `$WS_JSON` no es el JSON
  que esperás (por ejemplo, Herdr devolvió un error en vez de un resultado).
  Agregá un `echo "$WS_JSON"` justo después del comando para ver qué llegó
  realmente, antes de intentar parsearlo.
- **Los pane IDs no coinciden con los que esperabas, o el script rompe
  después de cerrar y volver a abrir cosas**: esto es esperado — Herdr
  documenta que los ids se reordenan. Por eso el tutorial siempre lee el id
  de la respuesta JSON anterior (con `jq`) en vez de hardcodearlo. Si
  escribiste un id a mano en algún lado, ese es el primer sospechoso.
- **`herdr workspace create` falla, o el agente no arranca**: revisá que no
  haya quedado un workspace viejo con el mismo `--label` de una sesión
  anterior que no se cerró bien (`herdr workspace list | jq
  '.result.workspaces[].label'` para listarlos todos).
- **Conflictos de puerto del agente** (el CLI del agente dice que el puerto
  ya está en uso): normalmente es una sesión anterior de ese mismo agente
  que quedó corriendo en otro pane/workspace que no se cerró. Usá `herdr
  workspace list` para encontrarlo y cerrarlo, en vez de abrir uno nuevo
  encima.
- **El `justfile` dice "command not found: just"**: falta instalar `just`
  (ver Nivel 5) o no está en el `PATH` de la shell actual — abrí una
  terminal nueva después de instalarlo.

---

## Extra — Auto-lanzar el layout al entrar a la carpeta (opcional)

Esto ya es un nivel más "avanzado / opinado": pensalo como algo para probar
cuando ya estés cómodo con los niveles anteriores, no como paso obligatorio.

### Hook de shell (zsh o fish)

Tanto zsh como fish tienen un hook que se dispara cada vez que cambiás de
carpeta (`cd`). Se puede usar para preguntar si querés levantar el layout de
Herdr apenas entrás a un proyecto que tiene `herdr-layout.yaml` o
`herdr-project.sh`:

```zsh
# en tu ~/.zshrc
chpwd() {
  if [ -f "./herdr-layout.yaml" ] && [ -z "$HERDR_AUTOLAUNCH_ASKED" ]; then
    export HERDR_AUTOLAUNCH_ASKED=1
    read "REPLY?Levantar layout de Herdr para este proyecto? (y/N) "
    [[ "$REPLY" == "y" ]] && herdr-spreader --config ./herdr-layout.yaml
  fi
}
```

(en fish sería una función equivalente con `--on-variable PWD`; la idea es
la misma).

**Por qué preguntar en vez de lanzarlo directo:** si no preguntás, terminás
con un workspace nuevo cada vez que simplemente pasás por una carpeta para
mirar un archivo — el hook se vuelve molesto en vez de útil.

### `direnv` para variables de entorno por proyecto

Si tu agente necesita variables de entorno específicas del proyecto (una API
key distinta por cliente, un modelo distinto, etc.),
[direnv](https://direnv.net/) es la forma estándar de manejarlo: creás un
archivo `.envrc` en la carpeta del proyecto con los `export` que necesites,
corrés `direnv allow` una vez, y esas variables quedan disponibles
automáticamente para cualquier pane que Herdr abra en esa carpeta (incluido
el agente).

```bash
# .envrc (en la raíz del proyecto)
export OPENCODE_MODEL="claude-sonnet-5"
export PROYECTO_ENV="development"
```

Esto es más prolijo que ponerlas en el `env:` del YAML de `herdr-spreader`
cuando son datos sensibles (una API key, por ejemplo) que no querés que
queden versionadas junto con el layout en el repo.

---

## Notas y dudas para la próxima sesión

- Falta confirmar el comando exacto del CLI de `antigravity` para meterlo en
  el layout de cualquiera de los dos plugins (no lo tenía a mano en esta
  sesión).
- Pendiente: ver `herdr session` (sesiones nombradas) si en algún momento
  querés separar completamente "trabajo" de "proyectos personales" a nivel
  de servidor, no solo de workspace.
- Pendiente: probar en la práctica si `herdr-spreader` acepta que el archivo
  YAML tenga cualquier nombre (ej. `herdr-layout.yaml`) o si espera un
  nombre fijo cuando se lo pasa por `--config` — la documentación oficial
  no lo especifica con un ejemplo 100% literal.
