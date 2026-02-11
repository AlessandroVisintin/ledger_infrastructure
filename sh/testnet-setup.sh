#!/bin/sh
set -eu

log() {
    echo "==> $1"
}

SHELL_FLD=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
ROOT_FLD="$SHELL_FLD/.."
ENV_PATH="$ROOT_FLD/.env.testnet"
COMPOSE_UTILS_FILE="$ROOT_FLD/docker/docker-compose.utils.yml"

# --- Configuration Loading ---
if [ -f "$ENV_PATH" ]; then
    log "Loading configuration from $ENV_PATH"
    set -a
    . "$ENV_PATH"
    set +a
else
    echo "ERROR: No .env file found at $ENV_PATH" >&2
    exit 1
fi

rm -rf "$TESTNET_FOLDER"

TESTNET_FLD="$TESTNET_FOLDER"
CA_FLD="$TESTNET_FLD/ca"
NODE_FLD="$TESTNET_FLD/node"
BUILD_FLD="$TESTNET_FLD/build"
NODE_KEY_FLD="$NODE_FLD/key"
NODE_CERT_FLD="$NODE_FLD/cert"

log "Configuration loaded. Target folder: $TESTNET_FLD"

# --- Node Authentication ---
log "Step 1/6: Generating RPC Authentication Credentials"

export OUTPUT_FOLDER="$NODE_FLD"

# Root User
echo "  -> Creating 'root' user credentials..."
export USERNAME="root"
export PASSWORD="rootPassword"
export PERMISSIONS="*:*"
docker compose -f "$COMPOSE_UTILS_FILE" run --rm rpc-auth-toml

# Eth User
echo "  -> Creating 'eth' user credentials..."
export USERNAME="eth"
export PASSWORD="ethPassword"
export PERMISSIONS="eth:*"
docker compose -f "$COMPOSE_UTILS_FILE" run --rm rpc-auth-toml

# EthChainId User
echo "  -> Creating 'ethChainId' user credentials..."
export USERNAME="ethChainId"
export PASSWORD="ethChainIdPassword"
export PERMISSIONS="eth:chainId"
docker compose -f "$COMPOSE_UTILS_FILE" run --rm rpc-auth-toml

# --- Node Certificate ---
log "Step 2/6: Generating TLS Certificates"

# CA Certificate
echo "  -> Generating Self-Signed CA..."
export OUTPUT_FOLDER="$CA_FLD"
docker compose -f "$COMPOSE_UTILS_FILE" run --rm certificate-self-signed

# Node Certificate
echo "  -> Generating Node Certificate (Signed by CA)..."
export OUTPUT_FOLDER="$NODE_CERT_FLD"
export CA_P12="$CA_FLD/cert.p12"
export P12_PASSWORD="password"
export SUBJECT="//CN=NODE 0"
export EXTENSION="subjectAltName=DNS:rpc-node-tls"

docker compose -f "$COMPOSE_UTILS_FILE" run --rm certificate-ca-signed

# --- Node Keys ---
log "Step 3/6: Generating Node Keys and Address"

export OUTPUT_FOLDER="$NODE_KEY_FLD"
export KEY_FILE="$NODE_KEY_FLD/key"

echo "  -> Generating Besu Keypair..."
docker compose -f "$COMPOSE_UTILS_FILE" run --rm besu-keygen

echo "  -> Exporting Node Address..."
docker compose -f "$COMPOSE_UTILS_FILE" run --rm besu-export-address

# --- Contracts ---
log "Step 4/6: Processing Genesis Contracts"

export OUTPUT_FOLDER="$TESTNET_FLD"
export INPUT_FILE="$CONTRACT_MANIFEST_PATH"

echo "  -> generating Genesis Contracts Registry..."
docker compose -f "$COMPOSE_UTILS_FILE" run --rm genesis-contracts-registry

export OUTPUT_FOLDER="$BUILD_FLD"
export CONTRACTS_REGISTRY="$TESTNET_FLD/genesis-contracts.json"
export CONTRACT_MANIFEST="$CONTRACT_MANIFEST_PATH"

echo "  -> Allocating Genesis Contract..."
docker compose -f "$COMPOSE_UTILS_FILE" run --rm genesis-alloc-contract

# --- Validators ---
log "Step 5/6: Configuring Validators"

export ADDRESS_FILE_PATH="$NODE_KEY_FLD/key.adr"
export VALIDATORS_LIST="$BUILD_FLD/validators-list.json"

echo "  -> Generating Validators List..."
docker compose -f "$COMPOSE_UTILS_FILE" run --rm genesis-validators-list

echo "  -> Generating QBFT Extra Data..."
docker compose -f "$COMPOSE_UTILS_FILE" run --rm genesis-qbft-extradata

# --- Genesis ---
log "Step 6/6: Assembling Final Genesis File"

export OUTPUT_FOLDER="$TESTNET_FLD"
export GENESIS_TEMPLATE="$GENESIS_TEMPLATE"
export GENESIS_EXTRADATA="$BUILD_FLD/genesis-extradata.txt"
export GENESIS_ALLOC="$BUILD_FLD/genesis-alloc.json"

docker compose -f "$COMPOSE_UTILS_FILE" run --rm genesis-generate

log "Testnet setup completed successfully."
log "Output available in: $TESTNET_FLD"
