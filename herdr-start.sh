#!/usr/bin/env bash
# herdr-start.sh — Abre el layout completo del proyecto herdr
set -euo pipefail

PROYECTO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABEL="$(basename "$PROYECTO_DIR")"   # auto-detecta el nombre del proyecto

# 1) Crear el workspace y capturar el id del pane raíz
WS_JSON=$(herdr workspace create --cwd "$PROYECTO_DIR" --label "$LABEL")
PANE_AGENTE=$(echo "$WS_JSON" | jq -r '.result.root_pane.pane_id')
WS_ID=$(echo "$WS_JSON" | jq -r '.result.workspace.workspace_id')

# 2) Renombrar el tab raíz con el nombre del proyecto
TAB_ROOT=$(echo "$WS_JSON" | jq -r '.result.root_pane.tab_id')
herdr tab rename "$TAB_ROOT" "opencode"

# 3) Arrancar opencode en el pane raíz
herdr pane run "$PANE_AGENTE" "opencode"

# 4) Crear un tab nuevo para agy
TAB_AGY=$(herdr tab create --workspace "$WS_ID" --label "agy" --no-focus)
PANE_AGY=$(echo "$TAB_AGY" | jq -r '.result.root_pane.pane_id')
herdr pane run "$PANE_AGY" "agy"

# 5) Crear un tab nuevo para pi
TAB_PI=$(herdr tab create --workspace "$WS_ID" --label "pi" --no-focus)
PANE_PI=$(echo "$TAB_PI" | jq -r '.result.root_pane.pane_id')
herdr pane run "$PANE_PI" "pi"

# 6) Crear un tab nuevo para git
TAB_GIT=$(herdr tab create --workspace "$WS_ID" --label "git" --no-focus)
PANE_GIT=$(echo "$TAB_GIT" | jq -r '.result.root_pane.pane_id')
herdr pane run "$PANE_GIT" "lazygit"

# 7) Crear un tab nuevo para glow
TAB_GLOW=$(herdr tab create --workspace "$WS_ID" --label "glow" --no-focus)
PANE_GLOW=$(echo "$TAB_GLOW" | jq -r '.result.root_pane.pane_id')
herdr pane run "$PANE_GLOW" "glow"

# 8) Crear un tab nuevo para terminal (shell vacía)
TAB_TERM=$(herdr tab create --workspace "$WS_ID" --label "terminal" --no-focus)
PANE_TERM=$(echo "$TAB_TERM" | jq -r '.result.root_pane.pane_id')
herdr pane run "$PANE_TERM" "bash"

echo "Workspace '$LABEL' listo. id=$WS_ID"
echo "Tabs: opencode | agy | pi | git | terminal"

# 9) Enfocar el workspace para que quede en primer plano
herdr workspace focus "$WS_ID"
