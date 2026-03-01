#!/usr/bin/env bash
# run.sh — Host-side launcher for the Docker agent sandbox.
#
# Usage:
#   ./run.sh                           # default (proxy on, name=agent-sandbox)
#   ./run.sh -n my-sandbox             # custom container name
#   ./run.sh --no-proxy                # disable allowlist proxy
#   ./run.sh --no-proxy -n my-sandbox  # both
#   ./run.sh -- --service-ports        # extra args after -- passed to docker compose run

set -euo pipefail

CONTAINER_NAME="pi-docker-sandbox"
NO_PROXY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
    -n | --name)
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

COMPOSE_FILES=(-f docker-compose.yml)
if [[ "$NO_PROXY" == false ]]; then
    COMPOSE_FILES+=(-f docker-compose.override.yml)
fi

echo "🚀 Starting agent sandbox (name=$CONTAINER_NAME, proxy=$([[ "$NO_PROXY" == false ]] && echo "on" || echo "off"))..."
docker compose "${COMPOSE_FILES[@]}" run --rm --build --name "$CONTAINER_NAME" "$@" sandbox
