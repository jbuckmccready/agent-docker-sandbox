#!/usr/bin/env bash
# run.sh — Host-side launcher for the Docker agent sandbox.
#
# Bridges notification signal files from the container into native OS
# notifications via a file watcher on the bind-mounted pi_config/notifications/.
#
# Usage:
#   ./run.sh                           # default (proxy on, name=agent-sandbox)
#   ./run.sh -n my-sandbox             # custom container name
#   ./run.sh --no-proxy                # disable allowlist proxy
#   ./run.sh --no-proxy -n my-sandbox  # both
#   ./run.sh -- --service-ports        # extra args after -- passed to docker compose run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTIFY_DIR="${SCRIPT_DIR}/pi_config/notifications"
WATCHER_PID=""
CONTAINER_NAME="agent-sandbox"
NO_PROXY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--name)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        --no-proxy)
            NO_PROXY=true
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            break
            ;;
    esac
done

if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    PLATFORM="wsl"
elif [[ "$(uname -s)" == "Darwin" ]]; then
    PLATFORM="macos"
else
    PLATFORM="linux"
fi

fire_notification() {
    local title="$1" body="$2"
    case "$PLATFORM" in
        macos)
            if command -v terminal-notifier &>/dev/null; then
                terminal-notifier -title "$title" -message "$body" -sound Ping &>/dev/null &
            elif command -v osascript &>/dev/null; then
                osascript -e "display notification \"$body\" with title \"$title\" sound name \"Ping\"" &>/dev/null &
            fi
            ;;
        linux)
            if command -v notify-send &>/dev/null; then
                notify-send "$title" "$body" &>/dev/null &
            fi
            ;;
        wsl)
            local safe_title="${title//\'/\\\'}"
            local safe_body="${body//\'/\\\'}"
            powershell.exe -Command "
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
(New-Object Media.SoundPlayer 'C:\Windows\Media\ding.wav').Play()
\$n = New-Object System.Windows.Forms.NotifyIcon
\$n.Icon = [System.Drawing.SystemIcons]::Information
\$n.BalloonTipTitle = '${safe_title}'
\$n.BalloonTipText = '${safe_body}'
\$n.Visible = \$true
\$n.ShowBalloonTip(5000)
Start-Sleep -Seconds 5
\$n.Dispose()
" &>/dev/null &
            ;;
    esac
}

process_notification_file() {
    local filepath="$1"
    [[ -f "$filepath" ]] || return
    local title body
    title="$(jq -r '.title // "Pi"' "$filepath" 2>/dev/null || echo "Pi")"
    body="$(jq -r '.body // ""' "$filepath" 2>/dev/null || echo "")"
    rm -f "$filepath"
    [[ -n "$body" ]] && fire_notification "$title" "$body"
}

start_watcher() {
    mkdir -p "$NOTIFY_DIR"

    if [[ "$PLATFORM" == "macos" ]]; then
        if ! command -v fswatch &>/dev/null; then
            echo "⚠  fswatch not found (brew install fswatch). Notifications won't be bridged."
            return
        fi
        fswatch -0 --event Created "$NOTIFY_DIR" | while IFS= read -r -d '' filepath; do
            [[ "$filepath" == *.json ]] && process_notification_file "$filepath"
        done &
    else
        if ! command -v inotifywait &>/dev/null; then
            echo "⚠  inotifywait not found (sudo apt install inotify-tools). Notifications won't be bridged."
            return
        fi
        inotifywait -m -q -e close_write --format '%w%f' "$NOTIFY_DIR" | while IFS= read -r filepath; do
            [[ "$filepath" == *.json ]] && process_notification_file "$filepath"
        done &
    fi
    WATCHER_PID=$!
}

cleanup() {
    [[ -n "$WATCHER_PID" ]] && kill "$WATCHER_PID" 2>/dev/null && wait "$WATCHER_PID" 2>/dev/null
    rm -f "$NOTIFY_DIR"/*.json 2>/dev/null
    true
}

trap cleanup EXIT INT TERM

start_watcher

COMPOSE_FILES=(-f docker-compose.yml)
if [[ "$NO_PROXY" == false ]]; then
    COMPOSE_FILES+=(-f docker-compose.override.yml)
fi

echo "🚀 Starting agent sandbox (name=$CONTAINER_NAME, proxy=$([[ "$NO_PROXY" == false ]] && echo "on" || echo "off"))..."
docker compose "${COMPOSE_FILES[@]}" run --rm --build --name "$CONTAINER_NAME" -e PI_NOTIFY_BRIDGE=1 "$@" sandbox
