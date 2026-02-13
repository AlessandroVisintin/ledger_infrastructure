#!/bin/sh
set -eu

SHELL_FLD=$(CDPATH= cd "$(dirname "$0")" && pwd -P)

ROOT_FLD="$SHELL_FLD/.."

COMPOSE_TEST_FILE="$ROOT_FLD/docker/docker-compose.test.yml"

docker compose -f "$COMPOSE_TEST_FILE" run --rm grype
