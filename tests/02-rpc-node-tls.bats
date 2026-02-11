#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

load "helpers.bash"

# Override curl to allow self-signed certificates for TLS tests
function curl() {
  command curl --cacert /app/ca.pem "$@"
}

setup() {
  NODE_ADDR="https://rpc-node-tls:8545"
  wait_rpc "$NODE_ADDR"
}

@test "Ensure normal HTTP RPC is disabled (connection rejected)" {  
  local payload='{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}'

  run command curl -v -sS --connect-timeout 2 \
    -H 'Content-Type: application/json' \
    --data-raw "$payload" \
    "http://rpc-node-tls:8545"

  [ "$status" -ne 0 ]
}

@test "TLS connection fails when using a different (mismatched) CA certificate" {
    local payload='{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}'

    run command curl -v -sS --connect-timeout 2 \
        -H "Content-Type: application/json" \
        --data-raw "$payload" \
        "$NODE_ADDR"
    
    [[ "$status" -eq 60 ]]
}

@test "SSL connection is established and returns valid chainId" {
  run -0 eth_chainId "$NODE_ADDR"
  [ "$output" = "1337" ]
}

@test "net_version is 2018 over TLS" {
  run -0 net_version "$NODE_ADDR"
  [ "$output" = "2018" ]
}
