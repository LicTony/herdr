#!/usr/bin/env bash
# herdr.sh — toggle workspace: si existe lo cierra, si no existe lo crea
#
# Version: 2.0.0
# Last modified: 2026-08-14
#
# Tab sources (in order):
#   1. Global: ${HERDR_GLOBAL_FILE:-~/herdrglobal}  (TSV: label<TAB>command)
#   2. Local:  ./herdr.tabs in the project dir       (same TSV format, optional)
set -euo pipefail

VERSION=$(grep '^# Version:' "${BASH_SOURCE[0]}" | awk '{print $3}')
echo "herdr v${VERSION}"

PROYECTO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABEL="$(basename "$PROYECTO_DIR")"

GLOBAL_TABS_FILE="${HERDR_GLOBAL_FILE:-${HOME}/herdrglobal}"
LOCAL_TABS_FILE="${PROYECTO_DIR}/herdr.tabs"

# Check HERDR_GLOBAL_FILE env var
if [[ -v HERDR_GLOBAL_FILE ]]; then
  echo "HERDR_GLOBAL_FILE=${HERDR_GLOBAL_FILE}"
else
  echo "herdr: warning: HERDR_GLOBAL_FILE no está definida, usando default: ${GLOBAL_TABS_FILE}" >&2
  echo "herdr: tip: agregá 'export HERDR_GLOBAL_FILE=/ruta/al/archivo' en tu ~/.bashrc" >&2
fi

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
  TAB_ROOT=$(herdr tab list --workspace "$WS_ID" | jq -r '.result.tabs[0].tab_id')
  PANE_AGENTE=$(herdr pane list --workspace "$WS_ID" | jq -r --arg tab "$TAB_ROOT" '.result.panes[] | select(.tab_id == $tab) | .pane_id' | head -1)

  herdr tab rename "$TAB_ROOT" "terminal"
  herdr pane run "$PANE_AGENTE" "bash"
else
  # Crear workspace nuevo
  WS_JSON=$(herdr workspace create --cwd "$PROYECTO_DIR" --label "$LABEL")
  PANE_AGENTE=$(echo "$WS_JSON" | jq -r '.result.root_pane.pane_id')
  WS_ID=$(echo "$WS_JSON" | jq -r '.result.workspace.workspace_id')

  TAB_ROOT=$(echo "$WS_JSON" | jq -r '.result.root_pane.tab_id')
  herdr tab rename "$TAB_ROOT" "terminal"
  herdr pane run "$PANE_AGENTE" "bash"
fi

# --- Crear tabs auxiliares ---

create_tab() {
  local label="$1" cmd="$2"
  local tab_json pane_id
  tab_json=$(herdr tab create --workspace "$WS_ID" --label "$label" --no-focus)
  pane_id=$(echo "$tab_json" | jq -r '.result.root_pane.pane_id')
  herdr pane run "$pane_id" "$cmd"
}

# Cargar tabs desde un archivo TSV (label<TAB>command).
# Líneas vacías y comentarios (#) se ignoran.
# Líneas malformadas (sin TAB) se skipean con warning.
load_tabs_from_file() {
  local file="$1"
  local line label cmd line_num=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    (( line_num++ )) || true
    # Ignorar comentarios y líneas vacías
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    # Validar que haya un TAB separador
    if [[ "$line" != *$'\t'* ]]; then
      echo "herdr: warning: ${file}:${line_num}: línea malformada (sin TAB), se ignora: '${line}'" >&2
      continue
    fi
    label="${line%%$'\t'*}"
    cmd="${line#*$'\t'}"
    create_tab "$label" "$cmd"
  done < "$file"
}

# 1) Tabs globales
TAB_LABELS="opencode"
if [[ -f "$GLOBAL_TABS_FILE" ]]; then
  load_tabs_from_file "$GLOBAL_TABS_FILE"
  TAB_LABELS+=" | $(grep -v '^[[:space:]]*#' "$GLOBAL_TABS_FILE" | grep $'\t' | awk -F$'\t' '{printf "%s | ", $1}' | sed 's/ | $//')"
else
  echo "herdr: warning: archivo global no encontrado: ${GLOBAL_TABS_FILE}" >&2
  echo "herdr: tip: creá el archivo o definí HERDR_GLOBAL_FILE en tu shell." >&2
fi

# 2) Tabs locales (opcional)
if [[ -f "$LOCAL_TABS_FILE" ]]; then
  load_tabs_from_file "$LOCAL_TABS_FILE"
  TAB_LABELS+=" | $(grep -v '^[[:space:]]*#' "$LOCAL_TABS_FILE" | grep $'\t' | awk -F$'\t' '{printf "%s | ", $1}' | sed 's/ | $//')"
fi

echo "Workspace '$LABEL' creado. id=$WS_ID"
echo "Tabs: ${TAB_LABELS}"

# Enfocar el workspace
herdr workspace focus "$WS_ID"
