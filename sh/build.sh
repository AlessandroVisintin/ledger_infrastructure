#!/bin/sh
set -eu

SHELL_FLD=$(CDPATH= cd "$(dirname "$0")" && pwd -P)

ROOT_FLD="$SHELL_FLD/.."
ENV_PATH="$ROOT_FLD/.env.testnet"

COMPOSE_BUILD_FILE="$ROOT_FLD/docker/docker-compose.build.yml"

if [ -f "$ENV_PATH" ]; then
    echo "Loading configuration from $ENV_PATH"
    set -a
    . "$ENV_PATH"
    set +a
else
    echo "ERROR: No .env file found at $ENV_PATH" >&2
    exit 1
fi

docker compose -f "$COMPOSE_BUILD_FILE" build
