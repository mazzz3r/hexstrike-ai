#!/usr/bin/env bash
set -euo pipefail

# Ensure we run from the application root
cd /opt/hexstrike

# Warn if the container is not running with root privileges. Several bundled
# network and password auditing tools require raw socket or privileged port
# access, which only work when the container runs as root.
if [ "$(id -u)" -ne 0 ]; then
    echo "[hexstrike] Warning: run the container as root to unlock full tooling." >&2
fi

# Create writable directories for runtime artefacts when backed by bind mounts
mkdir -p logs data cache workspace

# Allow callers to override host/port, but default to sensible container values
: "${HEXSTRIKE_HOST:=0.0.0.0}"
: "${HEXSTRIKE_PORT:=8888}"

# Activate the Python virtual environment if present
if [ -d "/opt/venv" ]; then
    # shellcheck disable=SC1091
    source /opt/venv/bin/activate
fi

exec "$@"
