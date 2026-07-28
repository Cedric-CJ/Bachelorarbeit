#!/usr/bin/env bash
set -Eeuo pipefail

APP_TITLE="n8n Launcher (lokal, ohne Docker)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

N8N_PORT="${N8N_PORT:-5678}"
N8N_PROTOCOL="${N8N_PROTOCOL:-http}"
N8N_LISTEN_ADDRESS="${N8N_LISTEN_ADDRESS:-0.0.0.0}"
N8N_FILES_DIR="${N8N_FILES_DIR:-$SCRIPT_DIR/testdaten}"
N8N_RESTRICT_FILE_ACCESS_TO="${N8N_RESTRICT_FILE_ACCESS_TO:-}"
N8N_BLOCK_ENV_ACCESS_IN_NODE="${N8N_BLOCK_ENV_ACCESS_IN_NODE:-false}"

OLLAMA_PORT="${OLLAMA_PORT:-11434}"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/n8n-local-launcher"
LOG_DIR="$STATE_DIR/logs"
PID_DIR="$STATE_DIR/pids"

N8N_LOG="$LOG_DIR/n8n.log"
OLLAMA_LOG="$LOG_DIR/ollama.log"
N8N_PID_FILE="$PID_DIR/n8n.pid"
OLLAMA_PID_FILE="$PID_DIR/ollama.pid"

mkdir -p "$LOG_DIR" "$PID_DIR"

STARTED_N8N=0
STARTED_OLLAMA=0
MODE=""
N8N_PUBLIC_BASE_URL=""
declare -a N8N_CMD

note() {
  local msg="$1"
  printf '%s %s\n' "$(date '+%F %T')" "$msg" >>"$N8N_LOG"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "$APP_TITLE" "$msg" || true
  fi
  printf '%s\n' "$msg"
}

print_usage() {
  cat <<'TXT'
Nutzung:
  ./start_n8n_lokal.sh                 # GUI/TUI-Auswahl
  ./start_n8n_lokal.sh --start-all     # n8n + Ollama starten
  ./start_n8n_lokal.sh --start-n8n     # nur n8n starten
  ./start_n8n_lokal.sh --stop          # vom Launcher gestartete Prozesse stoppen
  ./start_n8n_lokal.sh --help          # Hilfe

Optionale Umgebungsvariablen:
  N8N_FILES_DIR=<Ordner>               Primärer Dateipfad für File-Nodes
  N8N_RESTRICT_FILE_ACCESS_TO="dir1;dir2"  Manuelle Dateifreigabe
  N8N_BLOCK_ENV_ACCESS_IN_NODE=false   Erlaubt {{$env.*}} in Node-Expressions
TXT
}

require_cmd() {
  local cmd="$1"
  local hint="${2:-}"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Fehlt: $cmd"
    [[ -n "$hint" ]] && echo "$hint"
    exit 1
  fi
}

has_gui() {
  [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]
}

detect_lan_ip() {
  local ip=""
  if command -v ip >/dev/null 2>&1; then
    ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '/src/ {for (i=1; i<=NF; i++) if ($i == "src") {print $(i+1); exit}}')"
    if [[ -z "$ip" ]]; then
      ip="$(ip -4 addr show scope global 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1)"
    fi
  fi
  if [[ -z "$ip" ]]; then
    ip="127.0.0.1"
  fi
  printf '%s\n' "$ip"
}

pick_mode() {
  if has_gui && command -v kdialog >/dev/null 2>&1; then
    kdialog --title "$APP_TITLE" \
      --menu "Was soll gestartet werden?" \
      1 "n8n + Ollama" \
      2 "Nur n8n" \
      3 "Vom Launcher gestartete Prozesse stoppen" || true
  elif has_gui && command -v zenity >/dev/null 2>&1; then
    zenity --list --title="$APP_TITLE" \
      --text="Was soll gestartet werden?" \
      --column="Nr" --column="Aktion" \
      1 "n8n + Ollama" \
      2 "Nur n8n" \
      3 "Vom Launcher gestartete Prozesse stoppen" \
      --hide-column=1 --print-column=1 || true
  else
    if [[ ! -t 0 ]]; then
      note "Kein Dialog verfügbar. Nutze --start-all, --start-n8n oder --stop."
      printf '0\n'
      return
    fi
    cat >&2 <<'TXT'
1) n8n + Ollama
2) Nur n8n
3) Vom Launcher gestartete Prozesse stoppen
TXT
    local choice
    read -r -p "Auswahl [1/2/3]: " choice || choice=""
    printf '%s\n' "$choice"
  fi
}

pid_is_alive() {
  local pid_file="$1"
  [[ -f "$pid_file" ]] || return 1
  local pid
  pid="$(<"$pid_file")"
  [[ -n "$pid" ]] || return 1
  kill -0 "$pid" 2>/dev/null
}

port_has_listener() {
  local port="$1"

  if command -v ss >/dev/null 2>&1; then
    ss -ltn "sport = :${port}" 2>/dev/null | awk 'NR>1 {found=1} END {exit(found?0:1)}'
    return $?
  fi

  if command -v lsof >/dev/null 2>&1; then
    lsof -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
    return $?
  fi

  return 1
}

build_restricted_paths() {
  # Wenn explizit gesetzt, nicht überschreiben.
  if [[ -n "${N8N_RESTRICT_FILE_ACCESS_TO:-}" ]]; then
    return 0
  fi

  local -A seen=()
  local -a dirs=()
  local d

  for d in \
    "$N8N_FILES_DIR" \
    "$N8N_FILES_DIR/kp1-csv-cache" \
    "$HOME/.n8n-files" \
    "$HOME/.n8n/checkpoints" \
    "$HOME/.n8n/checkpoints/kp1c" \
    "$HOME/.n8n/checkpoints/kp3c" \
    "$SCRIPT_DIR" \
    "$SCRIPT_DIR/testdaten" \
    "$HOME/Downloads"; do
    [[ -n "$d" && -d "$d" && -z "${seen[$d]+x}" ]] || continue
    seen["$d"]=1
    dirs+=("$d")
  done

  if [[ "${#dirs[@]}" -eq 0 ]]; then
    dirs=("$HOME/.n8n-files")
  fi

  local IFS=';'
  N8N_RESTRICT_FILE_ACCESS_TO="${dirs[*]}"
}

stop_pid_file() {
  local pid_file="$1"
  local name="$2"
  if pid_is_alive "$pid_file"; then
    local pid
    pid="$(<"$pid_file")"
    kill "$pid" 2>/dev/null || true
    sleep 1
    if kill -0 "$pid" 2>/dev/null; then
      kill -9 "$pid" 2>/dev/null || true
    fi
    note "$name gestoppt (PID $pid)."
  fi
  rm -f "$pid_file"
}

stop_all() {
  stop_pid_file "$N8N_PID_FILE" "n8n"
  stop_pid_file "$OLLAMA_PID_FILE" "Ollama"

  if port_has_listener "$N8N_PORT"; then
    note "Auf Port ${N8N_PORT} antwortet weiterhin ein Dienst, der nicht ueber diese Launcher-PID-Datei verwaltet wird."
  fi
  if port_has_listener "$OLLAMA_PORT"; then
    note "Auf Port ${OLLAMA_PORT} antwortet weiterhin ein Dienst, der nicht ueber diese Launcher-PID-Datei verwaltet wird."
  fi
}

http_ready() {
  local url="$1"
  if command -v curl >/dev/null 2>&1; then
    curl -fsS --max-time 2 "$url" >/dev/null 2>&1
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- --timeout=2 "$url" >/dev/null 2>&1
  else
    return 1
  fi
}

wait_http() {
  local url="$1"
  local timeout_s="$2"
  local i
  for ((i=1; i<=timeout_s; i++)); do
    if http_ready "$url"; then
      return 0
    fi
    sleep 1
  done
  return 1
}

resolve_n8n_command() {
  if command -v n8n >/dev/null 2>&1; then
    N8N_CMD=(n8n start)
    return
  fi
  if command -v npx >/dev/null 2>&1; then
    N8N_CMD=(npx --yes n8n start)
    return
  fi
  echo "n8n nicht gefunden (weder 'n8n' noch 'npx')."
  echo "Installiere Node + npm und danach n8n."
  echo "Empfohlen unter Arch/CachyOS:"
  echo "  sudo pacman -S --needed nodejs-lts-krypton npm"
  echo "  sudo npm install -g n8n"
  exit 1
}

check_node_version() {
  if ! command -v node >/dev/null 2>&1; then
    echo "Node.js fehlt."
    echo "Installiere unter Arch/CachyOS: sudo pacman -S --needed nodejs-lts-krypton npm"
    echo "Danach: sudo npm install -g n8n"
    exit 1
  fi
  if ! node -e "const [M,m]=process.versions.node.split('.').map(Number); process.exit(((M>20||(M===20&&m>=19))&&M<=24)?0:1)"; then
    echo "Node.js-Version $(node -v) ist fuer n8n unpassend."
    echo "Benoetigt: >= 20.19 und <= 24.x"
    echo "Empfohlen unter Arch/CachyOS: sudo pacman -S --needed nodejs-lts-krypton npm"
    exit 1
  fi
}

ollama_ready() {
  http_ready "http://127.0.0.1:${OLLAMA_PORT}/api/tags"
}

check_docker_port_conflict() {
  if ! command -v docker >/dev/null 2>&1; then
    return 0
  fi
  if docker ps --format '{{.Names}} {{.Ports}}' 2>/dev/null | grep -Eq "n8n .*:${N8N_PORT}->"; then
    echo "Docker-Container 'n8n' belegt Port ${N8N_PORT}."
    echo "Bitte vorher stoppen: cd \"$SCRIPT_DIR\" && docker compose down"
    exit 1
  fi
}

cleanup() {
  if [[ "$STARTED_N8N" -eq 1 ]]; then
    stop_pid_file "$N8N_PID_FILE" "n8n"
  fi
  if [[ "$STARTED_OLLAMA" -eq 1 ]]; then
    stop_pid_file "$OLLAMA_PID_FILE" "Ollama"
  fi
}

start_ollama_if_requested() {
  [[ "$MODE" == "1" ]] || return 0
  require_cmd ollama "Installiere Ollama lokal und stelle sicher, dass 'ollama' im PATH ist."

  if ollama_ready; then
    note "Ollama laeuft bereits auf Port ${OLLAMA_PORT}."
  else
    note "Starte Ollama lokal..."
    (
      OLLAMA_HOST="127.0.0.1:${OLLAMA_PORT}" ollama serve >>"$OLLAMA_LOG" 2>&1
    ) &
    echo $! >"$OLLAMA_PID_FILE"
    STARTED_OLLAMA=1

    if ! wait_http "http://127.0.0.1:${OLLAMA_PORT}/api/tags" 20; then
      note "Ollama ist nicht erreichbar. Details: $OLLAMA_LOG"
      exit 1
    fi
  fi

}

start_n8n() {
  resolve_n8n_command
  check_node_version
  check_docker_port_conflict

  local lan_ip
  lan_ip="$(detect_lan_ip)"
  N8N_PUBLIC_BASE_URL="${N8N_PUBLIC_BASE_URL:-${N8N_PROTOCOL}://${lan_ip}:${N8N_PORT}}"

  if http_ready "http://127.0.0.1:${N8N_PORT}/"; then
    note "Auf Port ${N8N_PORT} antwortet bereits ein Dienst. Ich starte keinen zweiten n8n-Prozess."
    return 0
  fi

  note "Freigegebene Dateiordner: ${N8N_RESTRICT_FILE_ACCESS_TO}"
  note "Env-Zugriff in Expressions: N8N_BLOCK_ENV_ACCESS_IN_NODE=${N8N_BLOCK_ENV_ACCESS_IN_NODE}"
  note "Starte n8n lokal auf ${N8N_PUBLIC_BASE_URL} ..."
  (
    export N8N_PORT
    export N8N_PROTOCOL
    export N8N_LISTEN_ADDRESS
    export N8N_EDITOR_BASE_URL="$N8N_PUBLIC_BASE_URL"
    export WEBHOOK_URL="${N8N_PUBLIC_BASE_URL}/"
    export N8N_FILES_DIR
    export N8N_RESTRICT_FILE_ACCESS_TO
    export N8N_BLOCK_ENV_ACCESS_IN_NODE
    "${N8N_CMD[@]}" >>"$N8N_LOG" 2>&1
  ) &
  echo $! >"$N8N_PID_FILE"
  STARTED_N8N=1

  if ! wait_http "http://127.0.0.1:${N8N_PORT}/" 60; then
    note "n8n ist nicht gestartet. Details: $N8N_LOG"
    exit 1
  fi
}

open_browser() {
  if ! has_gui; then
    note "Keine GUI-Session erkannt. Browser wird nicht automatisch geoeffnet."
    return 0
  fi

  local url="http://127.0.0.1:${N8N_PORT}/home/workflows"
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url" >/dev/null 2>&1 || true
  else
    note "Browser nicht automatisch geoeffnet. URL: $url"
  fi
}

wait_for_control_window_close() {
  local msg="n8n Launcher laeuft.

- n8n: http://127.0.0.1:${N8N_PORT}
- LAN/Webhook: ${N8N_PUBLIC_BASE_URL:-nicht gesetzt}

Wenn du dieses Fenster schliesst, beendet der Launcher alle von ihm gestarteten Prozesse."

  if has_gui; then
    if command -v kdialog >/dev/null 2>&1; then
      kdialog --title "$APP_TITLE" --msgbox "$msg" || true
      return 0
    fi
    if command -v zenity >/dev/null 2>&1; then
      zenity --info --title="$APP_TITLE" --text="$msg" --width=520 || true
      return 0
    fi
  fi

  note "Kein GUI-Steuerfenster verfuegbar. Mit Strg+C beenden."
  while true; do
    sleep 2
  done
}

CLI_MODE="${1:-}"
case "$CLI_MODE" in
  --help|-h)
    print_usage
    exit 0
    ;;
  --start-all)
    MODE="1"
    ;;
  --start-n8n)
    MODE="2"
    ;;
  --stop)
    MODE="3"
    ;;
  "")
    MODE="$(pick_mode)"
    ;;
  *)
    echo "Unbekannte Option: $CLI_MODE"
    print_usage
    exit 1
    ;;
esac

if [[ -z "$MODE" || ! "$MODE" =~ ^[123]$ ]]; then
  echo "Abbruch."
  exit 0
fi

if [[ "$MODE" == "3" ]]; then
  stop_all
  exit 0
fi

if [[ ! -d "$N8N_FILES_DIR" ]]; then
  echo "Testdaten-Ordner fehlt: $N8N_FILES_DIR"
  echo "Setze N8N_FILES_DIR oder lege den Ordner an."
  exit 1
fi

mkdir -p "$N8N_FILES_DIR/kp1-csv-cache"
build_restricted_paths

trap cleanup EXIT

require_cmd awk
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
  echo "Bitte curl oder wget installieren."
  exit 1
fi

start_ollama_if_requested
start_n8n
open_browser

note "n8n laeuft. URL: http://127.0.0.1:${N8N_PORT}"
note "LAN/Webhook-Basis: ${N8N_PUBLIC_BASE_URL:-nicht gesetzt}"
note "Schliesse das Steuerfenster, um alle gestarteten Prozesse zu beenden."
wait_for_control_window_close
