#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

load "/app/helpers.bash"

setup() {
  NODE_ADDR="http://rpc-node:8545"
  wait_rpc "$NODE_ADDR"
}

@test "net_version is 2018 on dev" {
  run -0 net_version "$NODE_ADDR"
  [ "$output" = "2018" ]
}

@test "eth_chainId is 1337" {
  run -0 eth_chainId "$NODE_ADDR"
  [ "$output" = "1337" ]
}

@test "eth_blockNumber returns hex height" {
  run -0 eth_blockNumber "$NODE_ADDR"
  [[ "$output" = "0" ]]
}

@test "eth_syncing is false on dev" {
  run -0 eth_syncing "$NODE_ADDR"
  [ "$output" = "false" ]
}

@test "net_peerCount is 0x0 (0) for single node" {
  run -0 net_peerCount "$NODE_ADDR"
  [ "$output" = "0" ]
}