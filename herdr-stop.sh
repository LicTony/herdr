#!/usr/bin/env bash
# herdr-stop.sh — cierra el workspace de este proyecto por su label
set -euo pipefail
LABEL="$(basename "$(pwd)")"   # mismo criterio que herdr-start.sh

WS_ID=$(herdr workspace list | jq -r --arg label "$LABEL" \
  '[.result.workspaces[] | select(.label == $label)] | first | .workspace_id')

if [ -z "$WS_ID" ]; then
  echo "No encontré un workspace con label '$LABEL'"
  exit 1
fi

herdr workspace close "$WS_ID"
echo "Workspace '$LABEL' (id=$WS_ID) cerrado."
