#!/usr/bin/env bash
# herdr.sh — toggle workspace: si existe lo cierra, si no existe lo crea
#
# Version: 1.2.0
# Last modified: 2026-07-26
set -euo pipefail

VERSION=$(grep '^# Version:' "${BASH_SOURCE[0]}" | awk '{print $3}')
echo "herdr v${VERSION}"

PROYECTO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABEL="$(basename "$PROYECTO_DIR")"

# Buscar workspace existente por label
WS_INFO=$(herdr workspace list | jq -r --arg label "$LABEL" \
  '[.result.workspaces[] | select(.label == $label)] | first // empty')

if [ -n "$WS_INFO" ]; then
  WS_ID=$(echo "$WS_INFO" | jq -r '.workspace_id')
  TAB_COUNT=$(echo "$WS_INFO" | jq -r '.tab_count')

  # Si ya tiene más de un tab, es el workspace completo → cerrar (toggle off)
  if [ "$TAB_COUNT" -gt 1 ]; then
    herdr workspace close "$WS_ID"
    echo "Workspace '$LABEL' (id=$WS_ID) cerrado."
    exit 0
  fi

  # Si tiene un solo tab, es el shell vacío desde donde se corrió → poblar
  echo "Workspace '$LABEL' existe con 1 tab, poblando..."
  # Obtener tab_id y pane_id del único tab existente
  TAB_ROOT=$(herdr tab list --workspace "$WS_ID" | jq -r '.result.tabs[0].tab_id')
  PANE_AGENTE=$(herdr pane list --workspace "$WS_ID" | jq -r --arg tab "$TAB_ROOT" '.result.panes[] | select(.tab_id == $tab) | .pane_id' | head -1)

  # Renombrar el tab raíz y arrancar opencode
  herdr tab rename "$TAB_ROOT" "opencode"
  herdr pane run "$PANE_AGENTE" "opencode"
else
  # Crear workspace nuevo con todos los tabs
  WS_JSON=$(herdr workspace create --cwd "$PROYECTO_DIR" --label "$LABEL")
  PANE_AGENTE=$(echo "$WS_JSON" | jq -r '.result.root_pane.pane_id')
  WS_ID=$(echo "$WS_JSON" | jq -r '.result.workspace.workspace_id')

  # Renombrar el tab raíz y arrancar opencode
  TAB_ROOT=$(echo "$WS_JSON" | jq -r '.result.root_pane.tab_id')
  herdr tab rename "$TAB_ROOT" "opencode"
  herdr pane run "$PANE_AGENTE" "opencode"
fi

# --- Crear tabs auxiliares (tanto para workspace nuevo como existente con 1 tab) ---

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
