#!/bin/sh
set -eu

log() {
    echo "==> $1"
}

SHELL_FLD=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
ROOT_FLD="$SHELL_FLD/.."
ENV_PATH="$ROOT_FLD/.env.rescalenode"

COMPOSE_FILE="$ROOT_FLD/docker/docker-compose.utils.yml"

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

rm -rf "$RESCALENODE_FOLDER"

TESTNET_FLD="$RESCALENODE_FOLDER"
NODE_FLD="$TESTNET_FLD/node"
CA_FLD="$TESTNET_FLD/ca"
BUILD_FLD="$TESTNET_FLD/build"

NODE_CERT_FLD="$NODE_FLD/cert"
NODE_KEY_FLD="$NODE_FLD/key"

mkdir -p "$TESTNET_FLD"

log "Configuration loaded. Target folder: $TESTNET_FLD"

# --- Node Authentication ---
log "Step 1/6: Generating RPC Authentication Credentials"

export OUTPUT_FOLDER="$NODE_FLD"

export USERNAME="$USERNAME_ROOT"
export PASSWORD="$PASSWORD_ROOT"
export PERMISSIONS="$PERMISSIONS_ROOT"

docker compose -f "$COMPOSE_FILE" run --rm rpc-auth-toml

export USERNAME="$USERNAME_ETH"
export PASSWORD="$PASSWORD_ETH"
export PERMISSIONS="$PERMISSIONS_ETH"

docker compose -f "$COMPOSE_FILE" run --rm rpc-auth-toml

export USERNAME="$USERNAME_PUBLIC"
export PASSWORD="$PASSWORD_PUBLIC"
export PERMISSIONS="$PERMISSIONS_PUBLIC"

docker compose -f "$COMPOSE_FILE" run --rm rpc-auth-toml


# --- Node Certificate ---
log "Step 2/6: Generating TLS Certificates"

export OUTPUT_FOLDER="$CA_FLD"

docker compose -f "$COMPOSE_FILE" run --rm certificate-self-signed

export OUTPUT_FOLDER="$NODE_CERT_FLD"

export CA_P12="$CA_FLD/cert.p12"
export P12_PASSWORD="$NODE_P12_PASSWORD"
export SUBJECT="$CERT_SUBJECT"
export EXTENSION="$CERT_EXTENSION"

docker compose -f "$COMPOSE_FILE" run --rm certificate-ca-signed


# --- Node Keys ---
log "Step 3/6: Generating Node Keys and Address"

export OUTPUT_FOLDER="$NODE_KEY_FLD"
export KEY_FILE="$NODE_KEY_FLD/key"

docker compose -f "$COMPOSE_FILE" run --rm besu-keygen
docker compose -f "$COMPOSE_FILE" run --rm besu-export-address


# --- Contracts ---
log "Step 4/6: Processing Genesis Contracts"

export OUTPUT_FOLDER="$TESTNET_FLD"
export INPUT_FILE="$HASHMANAGER_MANIFEST_PATH"

docker compose -f "$COMPOSE_FILE" run --rm genesis-contracts-registry

export INPUT_FILE="$DAG_HASHMANAGER_MANIFEST_PATH"

docker compose -f "$COMPOSE_FILE" run --rm genesis-contracts-registry

export OUTPUT_FOLDER="$BUILD_FLD"
export CONTRACTS_REGISTRY="$TESTNET_FLD/genesis-contracts.json"
export CONTRACT_MANIFEST="$HASHMANAGER_MANIFEST_PATH"

docker compose -f "$COMPOSE_FILE" run --rm genesis-alloc-contract

export CONTRACT_MANIFEST="$DAG_HASHMANAGER_MANIFEST_PATH"

docker compose -f "$COMPOSE_FILE" run --rm genesis-alloc-contract


# --- Validators ---
log "Step 5/6: Configuring Validators"

export ADDRESS_FILE_PATH="$NODE_KEY_FLD/key.adr"

docker compose -f "$COMPOSE_FILE" run --rm genesis-validators-list

export VALIDATORS_LIST="$BUILD_FLD/validators-list.json"

docker compose -f "$COMPOSE_FILE" run --rm genesis-qbft-extradata


# --- Genesis ---
log "Step 6/6: Assembling Final Genesis File"

export OUTPUT_FOLDER="$TESTNET_FLD"
export GENESIS_TEMPLATE="$GENESIS_TEMPLATE"
export GENESIS_EXTRADATA="$BUILD_FLD/genesis-extradata.txt"
export GENESIS_ALLOC="$BUILD_FLD/genesis-alloc.json"

docker compose -f "$COMPOSE_FILE" run --rm genesis-generate


# --- Genesis ---
log "Building final image embedding /app/genesis.json and /app/node/*"

IMAGE_REPO="harbor.rescale-project.eu/rescale-all/besu"
IMAGE_DATE_TAG="$(date -u '+%Y-%m-%d')"
IMAGE_TAG="${IMAGE_TAG:-${IMAGE_REPO}:${IMAGE_DATE_TAG}}"

IMG_CTX="$(mktemp -d)"
cleanup() { rm -rf "$IMG_CTX"; }
trap cleanup EXIT

cp -f "$TESTNET_FLD/genesis.json" "$IMG_CTX/genesis.json"
cp -R "$NODE_FLD" "$IMG_CTX/node"

cat > "$IMG_CTX/Dockerfile" <<'EOF'
FROM rescale/base-image
USER root
WORKDIR /app
COPY --chown=besu:besu genesis.json /app/genesis.json
COPY --chown=besu:besu node /app/node
USER besu
EOF

docker build -t "$IMAGE_TAG" "$IMG_CTX"