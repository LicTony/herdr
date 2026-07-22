#!/usr/bin/env bash
# herdr.sh — toggle workspace: si existe lo cierra, si no existe lo crea
set -euo pipefail

PROYECTO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABEL="$(basename "$PROYECTO_DIR")"

# Buscar workspace existente por label
WS_ID=$(herdr workspace list | jq -r --arg label "$LABEL" \
  '[.result.workspaces[] | select(.label == $label)] | first | .workspace_id // empty')

if [ -n "$WS_ID" ]; then
  herdr workspace close "$WS_ID"
  echo "Workspace '$LABEL' (id=$WS_ID) cerrado."
  exit 0
fi

# --- Crear workspace con todos los tabs ---

# 1) Crear el workspace y capturar el id del pane raíz
WS_JSON=$(herdr workspace create --cwd "$PROYECTO_DIR" --label "$LABEL")
PANE_AGENTE=$(echo "$WS_JSON" | jq -r '.result.root_pane.pane_id')
WS_ID=$(echo "$WS_JSON" | jq -r '.result.workspace.workspace_id')

# 2) Renombrar el tab raíz y arrancar opencode
TAB_ROOT=$(echo "$WS_JSON" | jq -r '.result.root_pane.tab_id')
herdr tab rename "$TAB_ROOT" "opencode"
herdr pane run "$PANE_AGENTE" "opencode"

# 3) Crear tabs auxiliares
create_tab() {
  local label="$1" cmd="$2"
  local tab_json
  tab_json=$(herdr tab create --workspace "$WS_ID" --label "$label" --no-focus)
  local pane_id
  pane_id=$(echo "$tab_json" | jq -r '.result.root_pane.pane_id')
  herdr pane run "$pane_id" "$cmd"
}

create_tab "agy"      "agy"
create_tab "pi"       "pi"
create_tab "git"      "lazygit"
create_tab "glow"     "glow"
create_tab "terminal" "bash"
create_tab "tonyscode" "tonyscode"

echo "Workspace '$LABEL' creado. id=$WS_ID"
echo "Tabs: opencode | agy | pi | git | glow | terminal | tonyscode"

# 4) Enfocar el workspace
herdr workspace focus "$WS_ID"
