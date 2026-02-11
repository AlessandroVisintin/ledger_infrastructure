#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

load "helpers.bash"

setup() {
  NODE_ADDR="http://rpc-node-auth:8545"
  wait_rpc "$NODE_ADDR"
}

@test "unauthenticated RPC request fails" {
  local payload='{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}'

  run -0 curl -sS -o /dev/null -w '%{http_code}' \
    -H 'Content-Type: application/json' \
    --data-raw "$payload" \
    "$NODE_ADDR"

  [[ "$output" == "401" || "$output" == "403" ]]
}

@test "login is successful for all three users" {
  run login "$NODE_ADDR" "root" "rootPassword"
  [ "$status" -eq 0 ]
  [ -n "$output" ]

  run login "$NODE_ADDR" "eth" "ethPassword"
  [ "$status" -eq 0 ]
  [ -n "$output" ]

  run login "$NODE_ADDR" "ethChainId" "ethChainIdPassword"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "root user can successfully call web3 and eth methods" {
  token=$(login "$NODE_ADDR" "root" "rootPassword")
  
  local payload='{"jsonrpc":"2.0","method":"web3_clientVersion","params":[],"id":1}'
  run rpc_post_result "$NODE_ADDR" "$payload" "$token"
  [ "$status" -eq 0 ]

  run eth_chainId "$NODE_ADDR" "$token"
  [ "$status" -eq 0 ]
  [ "$output" = "1337" ]
}

@test "eth user can only call eth methods" {
  token=$(login "$NODE_ADDR" "eth" "ethPassword")
  
  run eth_chainId "$NODE_ADDR" "$token"
  [ "$status" -eq 0 ]
  [ "$output" = "1337" ]

  local payload='{"jsonrpc":"2.0","method":"web3_clientVersion","params":[],"id":1}'
  run rpc_post_result "$NODE_ADDR" "$payload" "$token"
  [ "$status" -ne 0 ]
}

@test "ethChainId can only call the specific eth method" {
  token=$(login "$NODE_ADDR" "ethChainId" "ethChainIdPassword")
  
  run eth_chainId "$NODE_ADDR" "$token"
  [ "$status" -eq 0 ]
  [ "$output" = "1337" ]

  run eth_blockNumber "$NODE_ADDR" "$token"
  [ "$status" -ne 0 ]
}