#!/usr/bin/env bash
set -Eeuo pipefail

APP_TITLE="n8n Launcher (lokal, ohne Docker)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILES_DIR_DEFAULT="$SCRIPT_DIR/testdaten"
FILES_DIR_ALT="/home/cedric/Dokumente/Dokumente/Dokumente/Hochschule/Module(586354)/WI/Bachlorarbeit zum Hochladen/n8n-Implementierung/testdaten"

if [[ -d "$FILES_DIR_ALT" ]]; then
  FILES_DIR_DEFAULT="$FILES_DIR_ALT"
fi

N8N_PORT="${N8N_PORT:-5678}"
N8N_PROTOCOL="${N8N_PROTOCOL:-http}"
N8N_LISTEN_ADDRESS="${N8N_LISTEN_ADDRESS:-0.0.0.0}"
N8N_FILES_DIR="${N8N_FILES_DIR:-$FILES_DIR_DEFAULT}"
N8N_CACHE_DIR="${N8N_CACHE_DIR:-$HOME/.n8n/kp1-csv-cache}"
N8N_RESTRICT_FILE_ACCESS_TO="${N8N_RESTRICT_FILE_ACCESS_TO:-}"
N8N_EXTRA_IMPORT_DIRS="${N8N_EXTRA_IMPORT_DIRS:-}"
N8N_ALLOW_ALL_FILE_ACCESS="${N8N_ALLOW_ALL_FILE_ACCESS:-false}"
N8N_BLOCK_ENV_ACCESS_IN_NODE="${N8N_BLOCK_ENV_ACCESS_IN_NODE:-false}"

OLLAMA_PORT="${OLLAMA_PORT:-11434}"
OLLAMA_MODEL="${OLLAMA_MODEL:-gemma4:e2b}"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/n8n-local-launcher"
LOG_DIR="$STATE_DIR/logs"
PID_DIR="$STATE_DIR/pids"
PROFILE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/n8n-local-browser-profile"

N8N_LOG="$LOG_DIR/n8n.log"
OLLAMA_LOG="$LOG_DIR/ollama.log"
N8N_PID_FILE="$PID_DIR/n8n.pid"
OLLAMA_PID_FILE="$PID_DIR/ollama.pid"

mkdir -p "$LOG_DIR" "$PID_DIR" "$N8N_CACHE_DIR"

STARTED_N8N=0
STARTED_OLLAMA=0
MODE=""
N8N_PUBLIC_BASE_URL=""
declare -a N8N_CMD

log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$N8N_LOG"; }

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
  ./start_n8n_lokal.sh --stop          # lokal gestartete Prozesse stoppen
  ./start_n8n_lokal.sh --status        # Status anzeigen
  ./start_n8n_lokal.sh --help          # Hilfe

Optionale Umgebungsvariablen:
  N8N_FILES_DIR=<Ordner>               Primärer Dateipfad für File-Nodes
  N8N_EXTRA_IMPORT_DIRS="dir1;dir2"    Zusätzliche erlaubte Import-Ordner
  N8N_ALLOW_ALL_FILE_ACCESS=true       Erlaubt Dateizugriff auf "/"
  N8N_BLOCK_ENV_ACCESS_IN_NODE=false   Erlaubt {{$env.*}} in Node-Expressions
TXT
}

is_true() {
  local value="${1:-}"
  value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
  [[ "$value" == "1" || "$value" == "true" || "$value" == "yes" || "$value" == "on" ]]
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
  local has_gui=0
  if [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
    has_gui=1
  fi

  if [[ "$has_gui" -eq 1 ]] && command -v kdialog >/dev/null 2>&1; then
    kdialog --title "$APP_TITLE" \
      --menu "Was soll gestartet werden?" \
      1 "n8n + Ollama" \
      2 "Nur n8n" \
      3 "Lokal gestartete Prozesse stoppen"
  elif [[ "$has_gui" -eq 1 ]] && command -v zenity >/dev/null 2>&1; then
    zenity --list --title="$APP_TITLE" \
      --text="Was soll gestartet werden?" \
      --column="Nr" --column="Aktion" \
      1 "n8n + Ollama" \
      2 "Nur n8n" \
      3 "Lokal gestartete Prozesse stoppen" \
      --hide-column=1 --print-column=1
  else
    if [[ ! -t 0 ]]; then
      note "Kein Dialog verfügbar. Nutze --start-all, --start-n8n oder --stop."
      printf '0\n'
      return
    fi
    cat >&2 <<'TXT'
1) n8n + Ollama
2) Nur n8n
3) Lokal gestartete Prozesse stoppen
TXT
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

pid_command_line() {
  local pid="$1"
  [[ -n "$pid" ]] || return 1
  [[ -r "/proc/$pid/cmdline" ]] || return 1
  tr '\0' ' ' <"/proc/$pid/cmdline"
}

is_n8n_process() {
  local pid="$1"
  local cmdline
  cmdline="$(pid_command_line "$pid" 2>/dev/null || true)"
  [[ -n "$cmdline" ]] || return 1
  [[ "$cmdline" == *" n8n start"* || "$cmdline" == n8n\ start* || "$cmdline" == *"/n8n start"* ]]
}

is_ollama_process() {
  local pid="$1"
  local cmdline
  cmdline="$(pid_command_line "$pid" 2>/dev/null || true)"
  [[ -n "$cmdline" ]] || return 1
  [[ "$cmdline" == *" ollama serve"* || "$cmdline" == ollama\ serve* || "$cmdline" == *"/ollama serve"* ]]
}

listener_pids_for_port() {
  local port="$1"

  if command -v ss >/dev/null 2>&1; then
    ss -ltnp "sport = :${port}" 2>/dev/null | sed -nE 's/.*pid=([0-9]+).*/\1/p' | sort -u
    return 0
  fi

  if command -v lsof >/dev/null 2>&1; then
    lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null | sort -u
    return 0
  fi
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

collect_service_pids() {
  local service="$1"
  declare -A seen=()
  declare -a out=()

  add_if_matching() {
    local pid="$1"
    [[ "$pid" =~ ^[0-9]+$ ]] || return 0
    [[ "$pid" -ne "$$" ]] || return 0
    kill -0 "$pid" 2>/dev/null || return 0

    case "$service" in
      n8n)
        is_n8n_process "$pid" || return 0
        ;;
      ollama)
        is_ollama_process "$pid" || return 0
        ;;
      *)
        return 0
        ;;
    esac

    if [[ -z "${seen[$pid]+x}" ]]; then
      seen["$pid"]=1
      out+=("$pid")
    fi
  }

  local pid
  case "$service" in
    n8n)
      while read -r pid; do
        add_if_matching "$pid"
      done < <(listener_pids_for_port "$N8N_PORT" || true)
      while read -r pid; do
        add_if_matching "$pid"
      done < <(pgrep -u "$(id -u)" -f "n8n start" || true)
      ;;
    ollama)
      while read -r pid; do
        add_if_matching "$pid"
      done < <(listener_pids_for_port "$OLLAMA_PORT" || true)
      while read -r pid; do
        add_if_matching "$pid"
      done < <(pgrep -u "$(id -u)" -f "ollama serve" || true)
      ;;
  esac

  if [[ "${#out[@]}" -gt 0 ]]; then
    printf '%s\n' "${out[@]}"
  fi
}

collect_foreign_service_pids() {
  local service="$1"
  local current_uid
  current_uid="$(id -u)"
  declare -A seen=()
  declare -a out=()

  local pattern=""
  case "$service" in
    n8n) pattern="n8n start" ;;
    ollama) pattern="ollama serve" ;;
    *) return 0 ;;
  esac

  local pid uid
  while read -r pid; do
    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    [[ "$pid" -ne "$$" ]] || continue

    uid="$(awk '/^Uid:/{print $2}' "/proc/$pid/status" 2>/dev/null || true)"
    [[ -n "$uid" ]] || continue
    [[ "$uid" != "$current_uid" ]] || continue

    if [[ -z "${seen[$pid]+x}" ]]; then
      seen["$pid"]=1
      out+=("$pid")
    fi
  done < <(pgrep -f "$pattern" 2>/dev/null || true)

  if [[ "${#out[@]}" -gt 0 ]]; then
    printf '%s\n' "${out[@]}"
  fi
}

build_restricted_paths() {
  # Wenn explizit gesetzt, nicht überschreiben.
  if [[ -n "${N8N_RESTRICT_FILE_ACCESS_TO:-}" ]]; then
    return 0
  fi

  if is_true "$N8N_ALLOW_ALL_FILE_ACCESS"; then
    N8N_RESTRICT_FILE_ACCESS_TO="/"
    return 0
  fi

  declare -A seen=()
  declare -a dirs=()

  add_dir() {
    local dir="$1"
    [[ -n "$dir" ]] || return 0
    [[ -d "$dir" ]] || return 0
    if [[ -z "${seen[$dir]+x}" ]]; then
      seen["$dir"]=1
      dirs+=("$dir")
    fi
  }

  add_dir "$N8N_FILES_DIR"
  add_dir "$N8N_CACHE_DIR"
  add_dir "$HOME/.n8n-files"
  add_dir "$HOME/.n8n/checkpoints"
  add_dir "$HOME/.n8n/checkpoints/kp1c"
  add_dir "$HOME/.n8n/checkpoints/kp3c"
  add_dir "$SCRIPT_DIR"
  add_dir "$SCRIPT_DIR/testdaten"
  add_dir "$FILES_DIR_ALT"
  add_dir "$FILES_DIR_PREVIEW"
  add_dir "$HOME/Downloads"

  if [[ -n "$N8N_EXTRA_IMPORT_DIRS" ]]; then
    local old_ifs="$IFS"
    IFS=';'
    read -r -a extra_dirs <<<"$N8N_EXTRA_IMPORT_DIRS"
    IFS="$old_ifs"
    local d
    for d in "${extra_dirs[@]}"; do
      add_dir "$d"
    done
  fi

  if [[ "${#dirs[@]}" -eq 0 ]]; then
    dirs=("$HOME/.n8n-files")
  fi

  local joined=""
  local d
  for d in "${dirs[@]}"; do
    if [[ -z "$joined" ]]; then
      joined="$d"
    else
      joined="$joined;$d"
    fi
  done
  N8N_RESTRICT_FILE_ACCESS_TO="$joined"
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

stop_orphan_service() {
  local service="$1"
  local pid_file="$2"
  local name="$3"
  local tracked_pid=""
  [[ -f "$pid_file" ]] && tracked_pid="$(<"$pid_file")"

  local pid
  while read -r pid; do
    [[ -n "$pid" ]] || continue
    if [[ -n "$tracked_pid" && "$pid" == "$tracked_pid" ]]; then
      continue
    fi
    kill "$pid" 2>/dev/null || true
    sleep 1
    if kill -0 "$pid" 2>/dev/null; then
      kill -9 "$pid" 2>/dev/null || true
    fi
    note "$name gestoppt (verwaist, PID $pid)."
  done < <(collect_service_pids "$service")
}

stop_all() {
  stop_pid_file "$N8N_PID_FILE" "n8n"
  stop_pid_file "$OLLAMA_PID_FILE" "Ollama"
  stop_orphan_service "n8n" "$N8N_PID_FILE" "n8n"
  stop_orphan_service "ollama" "$OLLAMA_PID_FILE" "Ollama"

  mapfile -t n8n_foreign_pids < <(collect_foreign_service_pids "n8n")
  if [[ "${#n8n_foreign_pids[@]}" -gt 0 ]]; then
    note "n8n-Prozesse anderer User/root konnten nicht beendet werden (PID(s): ${n8n_foreign_pids[*]})."
  fi
  mapfile -t ollama_foreign_pids < <(collect_foreign_service_pids "ollama")
  if [[ "${#ollama_foreign_pids[@]}" -gt 0 ]]; then
    note "Ollama-Prozesse anderer User/root konnten nicht beendet werden (PID(s): ${ollama_foreign_pids[*]})."
  fi

  if port_has_listener "$N8N_PORT"; then
    note "Auf Port ${N8N_PORT} laeuft weiterhin ein Dienst, der nicht vom Launcher verwaltet wird (evtl. anderer User/root oder Docker)."
  fi
  if port_has_listener "$OLLAMA_PORT"; then
    note "Auf Port ${OLLAMA_PORT} laeuft weiterhin ein Dienst, der nicht vom Launcher verwaltet wird (evtl. systemweiter Ollama-Service)."
  fi
}

print_status() {
  if pid_is_alive "$N8N_PID_FILE"; then
    echo "n8n: läuft (PID $(<"$N8N_PID_FILE"))"
  else
    mapfile -t n8n_pids < <(collect_service_pids "n8n")
    if [[ "${#n8n_pids[@]}" -gt 0 ]]; then
      echo "n8n: läuft (verwaist, PID(s): ${n8n_pids[*]})"
    else
      mapfile -t n8n_foreign_pids < <(collect_foreign_service_pids "n8n")
      if [[ "${#n8n_foreign_pids[@]}" -gt 0 ]]; then
        echo "n8n: laeuft (nicht vom Launcher verwaltbar, fremder User/root, PID(s): ${n8n_foreign_pids[*]})"
      elif port_has_listener "$N8N_PORT"; then
        echo "n8n: laeuft (nicht vom Launcher verwaltbar, vermutlich anderer User/root oder Docker)"
      else
        echo "n8n: nicht aktiv"
      fi
    fi
  fi
  if pid_is_alive "$OLLAMA_PID_FILE"; then
    echo "Ollama: läuft (PID $(<"$OLLAMA_PID_FILE"))"
  else
    mapfile -t ollama_pids < <(collect_service_pids "ollama")
    if [[ "${#ollama_pids[@]}" -gt 0 ]]; then
      echo "Ollama: läuft (verwaist, PID(s): ${ollama_pids[*]})"
    else
      mapfile -t ollama_foreign_pids < <(collect_foreign_service_pids "ollama")
      if [[ "${#ollama_foreign_pids[@]}" -gt 0 ]]; then
        echo "Ollama: laeuft (nicht vom Launcher verwaltbar, fremder User/root, PID(s): ${ollama_foreign_pids[*]})"
      elif port_has_listener "$OLLAMA_PORT"; then
        echo "Ollama: laeuft (nicht vom Launcher verwaltbar, vermutlich systemweit/root)"
      else
        echo "Ollama: nicht aktiv"
      fi
    fi
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

  if command -v curl >/dev/null 2>&1; then
    if ! curl -fsS "http://127.0.0.1:${OLLAMA_PORT}/api/tags" | grep -Fq "\"name\":\"${OLLAMA_MODEL}\""; then
      note "Hinweis: Modell '${OLLAMA_MODEL}' nicht gefunden. Bei Bedarf: ollama pull ${OLLAMA_MODEL}"
    fi
  fi
}

start_n8n() {
  resolve_n8n_command
  check_node_version
  check_docker_port_conflict

  if http_ready "http://127.0.0.1:${N8N_PORT}/"; then
    note "Auf Port ${N8N_PORT} antwortet bereits ein Dienst. Ich starte keinen zweiten n8n-Prozess."
    return 0
  fi

  local lan_ip
  lan_ip="$(detect_lan_ip)"
  N8N_PUBLIC_BASE_URL="${N8N_PUBLIC_BASE_URL:-${N8N_PROTOCOL}://${lan_ip}:${N8N_PORT}}"

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
    export N8N_CACHE_DIR
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
  if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
    note "Keine GUI-Session erkannt. Browser wird nicht automatisch geoeffnet."
    return 0
  fi

  local url="http://127.0.0.1:${N8N_PORT}/home/workflows"
  local browser=""
  local b
  for b in chromium chromium-browser google-chrome-stable google-chrome brave brave-browser vivaldi-stable microsoft-edge-stable; do
    if command -v "$b" >/dev/null 2>&1; then
      browser="$b"
      break
    fi
  done

  if [[ -n "$browser" ]]; then
    "$browser" --app="$url" --user-data-dir="$PROFILE_DIR" --class="n8n-local-app" >/dev/null 2>&1 &
  else
    xdg-open "$url" >/dev/null 2>&1 || true
  fi
}

wait_for_control_window_close() {
  local msg="n8n Launcher laeuft.

- n8n: http://127.0.0.1:${N8N_PORT}
- LAN/Webhook: ${N8N_PUBLIC_BASE_URL:-nicht gesetzt}

Wenn du dieses Fenster schliesst, beendet der Launcher alle von ihm gestarteten Prozesse."

  if [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
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
  --status)
    print_status
    exit 0
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

build_restricted_paths

if [[ "$MODE" == "3" ]]; then
  stop_all
  exit 0
fi

if [[ ! -d "$N8N_FILES_DIR" ]]; then
  echo "Testdaten-Ordner fehlt: $N8N_FILES_DIR"
  echo "Setze N8N_FILES_DIR oder lege den Ordner an."
  exit 1
fi

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
