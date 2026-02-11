#!/bin/sh
set -eu

SHELL_FLD=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
ROOT_FLD="$SHELL_FLD/.."
ENV_PATH="$ROOT_FLD/.env.testnet"
COMPOSE_FILE="$ROOT_FLD/docker/docker-compose.test.yml"

TESTS_FLD="$ROOT_FLD/tests"

# --- Configuration Loading ---
if [ -f "$ENV_PATH" ]; then
    echo "Loading configuration from $ENV_PATH"
    set -a
    . "$ENV_PATH"
    set +a
else
    echo "ERROR: No .env file found at $ENV_PATH" >&2
    exit 1
fi

TESTNET_FLD="$TESTNET_FOLDER"

CA_FLD="$TESTNET_FLD/ca"
NODE_FLD="$TESTNET_FLD/node"
NODE_CERT_FLD="$NODE_FLD/cert"
NODE_KEY_FLD="$NODE_FLD/key"

export HELPERS_FILE="$TESTS_FLD/helpers.bash"

#
export TEST_FILE="$TESTS_FLD/00-rpc-node.bats"

docker compose -f "$COMPOSE_FILE" up -d rpc-node
docker compose -f "$COMPOSE_FILE" run --rm tester
docker compose -f "$COMPOSE_FILE" down

#
export AUTH_FILE="$NODE_FLD/auth.toml"
export TEST_FILE="$TESTS_FLD/01-rpc-node-auth.bats"

docker compose -f "$COMPOSE_FILE" up -d rpc-node-auth
docker compose -f "$COMPOSE_FILE" run --rm tester
docker compose -f "$COMPOSE_FILE" down

#
export P12_FILE="$NODE_CERT_FLD/cert.p12"
export P12_PASS_FILE="$NODE_CERT_FLD/password.txt"
export TEST_FILE="$TESTS_FLD/02-rpc-node-tls.bats"
export CA_CERT_FILE="$CA_FLD/cert.pem"

docker compose -f "$COMPOSE_FILE" up -d rpc-node-tls
docker compose -f "$COMPOSE_FILE" run --rm tester
docker compose -f "$COMPOSE_FILE" down

#
export TEST_FILE="$TESTS_FLD/03-p2p-nodes.bats"

docker compose -f "$COMPOSE_FILE" up -d p2p-node-1
docker compose -f "$COMPOSE_FILE" up -d p2p-node-2
docker compose -f "$COMPOSE_FILE" run --rm tester
docker compose -f "$COMPOSE_FILE" down

#
export GENESIS_FILE="$TESTNET_FLD/genesis.json"
export ADDRESS_FILE="$NODE_KEY_FLD/key.adr"
export KEY_FILE="$NODE_KEY_FLD/key"
export TEST_FILE="$TESTS_FLD/04-genesis-node.bats"

docker compose -f "$COMPOSE_FILE" up -d genesis-node
docker compose -f "$COMPOSE_FILE" run --rm tester
docker compose -f "$COMPOSE_FILE" down
