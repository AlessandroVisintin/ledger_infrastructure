# LedgerInfrastructure

LedgerInfrastructure is a small toolkit for building and testing Hyperledger Besu (an Ethereum client) node setups with Docker Compose.
It focuses on QBFT (a Byzantine-fault-tolerant consensus) genesis generation, plus optional JSON-RPC authentication and TLS.

## Key features

- Builds a pinned Besu-based image plus small Alpine utility/test images.
- Generates a QBFT-ready `genesis.json` from a template and a validators list, with optional “genesis contracts” pre-allocation.
- Generates RPC authentication credentials in `auth.toml`, including per-user permissions.
- Generates a self-signed Certificate Authority (CA) and a node TLS PKCS#12 keystore for HTTPS JSON-RPC tests.
- Runs automated integration tests with Bats (Bash Automated Testing System) for RPC, auth, TLS, P2P peering, and genesis correctness.
- Provides two workflows: a local “testnet” artifacts folder and a “rescalenode” workflow that bakes generated artifacts into a final Docker image.

## What you need

- Docker and Docker Compose.
- A POSIX shell to run the scripts under `sh/`.
- For the “rescalenode” workflow, you must provide two external contract manifest JSON files via `HASHMANAGER_MANIFEST_PATH` and `DAG_HASHMANAGER_MANIFEST_PATH`.

## Quick start

### Install

1. Clone/download the repository.
2. Ensure Docker is running on your machine.

### Configure (env files)

This repo uses two separate environment files at the repository root: `.env.testnet` (local testnet integration tests) and `.env.rescalenode` (rescalenode image flow).
The scripts load them by sourcing the file, so keep the format shell-compatible (no spaces around `=`, quote values if needed).

Start by copying the provided examples and then editing them to match your machine: `.env.testnet.example` → `.env.testnet`, `.env.rescalenode.example` → `.env.rescalenode`.

### Run (local testnet + tests)

1) Build the Docker images:

```sh
sh sh/build.sh
```  


2) Generate testnet artifacts:

```sh
sh sh/testnet-setup.sh
```  


3) Run the integration tests:

```sh
sh sh/testnet-test.sh
```  


### How to confirm it’s working

If everything is set up correctly, `sh/testnet-test.sh` should bring up Docker Compose services and run Bats tests against them, then tear everything down.
Those tests cover RPC, RPC with auth, RPC over TLS, P2P, and a custom genesis node.


### How to confirm it’s working

If everything is set up correctly, `sh/testnet-test.sh` brings up Docker Compose services, runs the Bats tests against them, and then tears everything down.
Those tests cover plain RPC, RPC with auth, RPC over TLS, P2P, and a custom “genesis node” scenario.

For a quick manual check of the plain RPC node, `docker/docker-compose.test.yml` starts `rpc-node` with HTTP JSON-RPC on port `8545`.

## How to use it

### Typical local testnet flow

Run artifact generation, then run the test suite.
Artifact generation is done by `sh/testnet-setup.sh`, and tests are executed by `sh/testnet-test.sh`.

If you want to manually poke the “plain RPC” node, you can start it with Docker Compose and call JSON-RPC on port 8545.
For example, `docker/docker-compose.test.yml` starts `rpc-node` with `--rpc-http-port=8545` and exposes it inside the Compose network as `http://rpc-node:8545`.

### “Rescalenode” image flow

The `sh/rescalenode-setup.sh` script generates a node folder plus `genesis.json`, then builds a Docker image that copies them into an image based on `rescale/base-image`.
By default it tags the final image as `harbor.rescale-project.eu/rescale-all/besu:<YYYY-MM-DD>`, and you can override the tag with `IMAGE_TAG`.

Minimal steps: create `.env.rescalenode` at the repo root, then run the script.
```sh
sh sh/rescalenode-setup.sh
```


## Configuration

### Environment variables

The scripts read configuration from `.env.testnet` / `.env.rescalenode`, and the repo provides examples in `.env.testnet.example` and `.env.rescalenode.example`.

#### `.env.testnet` (local testnet + integration tests)

Used by `sh/build.sh`, `sh/testnet-setup.sh`, and `sh/testnet-test.sh`.

| Name | What it does |
|---|---|
| `ALPINE_VERSION` | Alpine tag used to build the utility/test images (used by `docker/docker-compose.build.yml`).  |
| `BESU_VERSION` | Hyperledger Besu tag used to build Besu-based images (used by `docker/docker-compose.build.yml`).  |
| `GENESIS_TEMPLATE` | Path to a genesis template JSON used during genesis generation (e.g., `assets/genesis/qbft-freegas.json`).  |
| `CONTRACT_MANIFEST_PATH` | Contract manifest JSON used to create a “genesis contracts registry” and allocate contract code into genesis (example file in repo: `assets/contracts/Counter.json`).  |
| `TESTNET_FOLDER` | Output folder for generated artifacts; it will be deleted/recreated by `sh/testnet-setup.sh` and used by `sh/testnet-test.sh`.  |

#### `.env.rescalenode` (rescalenode image build)

Used by `sh/rescalenode-setup.sh`.

| Name | What it does |
|---|---|
| `GENESIS_TEMPLATE` | Path to the genesis template JSON used during genesis generation.  |
| `RESCALENODE_FOLDER` | Output folder for the rescalenode build; it is deleted/recreated by `sh/rescalenode-setup.sh`.  |
| `USERNAME_ROOT`, `PASSWORD_ROOT`, `PERMISSIONS_ROOT` | JSON-RPC auth user (root) credentials/permissions.  |
| `USERNAME_ETH`, `PASSWORD_ETH`, `PERMISSIONS_ETH` | JSON-RPC auth user (eth) credentials/permissions.  |
| `USERNAME_PUBLIC`, `PASSWORD_PUBLIC`, `PERMISSIONS_PUBLIC` | JSON-RPC auth user (public) credentials/permissions.  |
| `NODE_P12_PASSWORD` | Password used to encrypt the generated node PKCS#12 keystore (also written to `password.txt`).  |
| `CERT_SUBJECT` | X.509 subject used for the node certificate request (passed to OpenSSL).  |
| `CERT_EXTENSION` | X.509 extension passed to OpenSSL (e.g., `subjectAltName=DNS:...`).  |
| `HASHMANAGER_MANIFEST_PATH` | Required external contract manifest input used in the rescalenode genesis-contract steps.  |
| `DAG_HASHMANAGER_MANIFEST_PATH` | Same as above, for the second external contract manifest input.  |
| `IMAGE_TAG` | Optional override for the final Docker image tag produced by `sh/rescalenode-setup.sh`.  |

## Project structure

```text
LedgerInfrastructure/
├── README.md
├── LICENSE
├── .env.testnet.example
├── .env.rescalenode.example
├── assets/
│   ├── contracts/
│   │   └── Counter.json
│   └── genesis/
│       └── qbft-freegas.json
├── docker/
│   ├── docker-compose.build.yml
│   ├── docker-compose.test.yml
│   └── docker-compose.utils.yml
├── sh/
│   ├── build.sh
│   ├── testnet-setup.sh
│   ├── testnet-test.sh
│   └── rescalenode-setup.sh
├── tests/
│   ├── 00-rpc-node.bats
│   ├── 01-rpc-node-auth.bats
│   ├── 02-rpc-node-tls.bats
│   ├── 03-p2p-nodes.bats
│   ├── 04-genesis-node.bats
│   └── helpers.bash
```

## Development

### Install dev deps

There is no language-level dependency file in this repository because the tooling runs inside Docker containers.
For development, you mainly need Docker/Docker Compose and a POSIX shell to run scripts in `sh/`.

### Tests

Run the full integration suite :
```sh
sh sh/testnet-test.sh
```  

The test runner script starts specific Docker Compose services and executes a Bats test file via the `tester` container, repeating this for each test group.
The individual Bats files live under `tests/`.


## License

This project is licensed under the **MIT License**. See the `LICENSE` file for full details.