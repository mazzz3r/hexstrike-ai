#!/usr/bin/env bash
set -euo pipefail

# Ensure we run from the application root
cd /opt/hexstrike

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
