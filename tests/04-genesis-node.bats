#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

load "helpers.bash"

setup() {
  NODE_ADDR="http://genesis-node:8545"
  wait_rpc "$NODE_ADDR"

  CONTRACT_ADR=$(jq -r '.alloc | to_entries[] | select(.value.code != null and (.value.code | length) > 10) | .key' /app/genesis.json | head -n1)
}

@test "eth_chainId matches genesis chainId (20261001)" {
  run -0 eth_chainId "$NODE_ADDR"
  [ "$output" = "20261001" ]
}

@test "Genesis block gasLimit matches genesis file (0x1fffffffffffff)" {
  local payload='{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["0x0",false],"id":1}'

  run rpc_post_result "$NODE_ADDR" "$payload"
  [ "$status" -eq 0 ]

  local gas_limit
  gas_limit="$(printf '%s' "$output" | jq -r '.gasLimit')"
  [ "$gas_limit" = "0x1fffffffffffff" ]
}

@test "Genesis block difficulty matches genesis file (0x1)" {
  local payload='{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["0x0",false],"id":1}'

  run rpc_post_result "$NODE_ADDR" "$payload"
  [ "$status" -eq 0 ]

  local difficulty
  difficulty="$(printf '%s' "$output" | jq -r '.difficulty')"
  [ "$difficulty" = "0x1" ]
}

@test "Genesis block mixHash matches genesis file (all zeros)" {
  local payload='{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["0x0",false],"id":1}'

  run rpc_post_result "$NODE_ADDR" "$payload"
  [ "$status" -eq 0 ]

  local mix_hash
  mix_hash="$(printf '%s' "$output" | jq -r '.mixHash')"
  [ "$mix_hash" = "0x0000000000000000000000000000000000000000000000000000000000000000" ]
}

@test "Shanghai is active at genesis (withdrawalsRoot present)" {
    local payload='{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["0x0",false],"id":1}'
    run rpc_post_error "$NODE_ADDR" "$payload"
    [ "$status" -eq 0 ]

    local withdrawals
    withdrawals=$(printf '%s' "$output" | jq -c '.result.withdrawals // empty')
    [ "$withdrawals" = "[]" ]
}

@test "QBFT has been correctly picked up (QBFT JSON-RPC returns expected validators at genesis)" {
  local payload='{"jsonrpc":"2.0","method":"qbft_getValidatorsByBlockNumber","params":["latest"],"id":1}'
  run rpc_post_error "$NODE_ADDR" "$payload"

  [ "$status" -eq 0 ]

  local count
  count="$(printf "%s" "$output" | jq -r '.result | length')"
  [ "$count" -eq 1 ]

  local actual expected
  actual="$(printf "%s" "$output" | jq -r '.result[0]' | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')"
  expected="$(tr -d '[:space:]' < /app/key.adr | tr '[:upper:]' '[:lower:]')"

  [ -n "$actual" ]
  [ "$actual" = "$expected" ]
}

@test "Counter number() returns 0 (constructor not run in genesis-alloc)" {
  local data=0x8381f58a  # function selector for number()
  local payload
  payload=$(jq -n \
    --arg to "$CONTRACT_ADR" \
    --arg data "$data" \
    '{"jsonrpc":"2.0","method":"eth_call","params":[{"to":$to, "data":$data}, "latest"],"id":1}')
  
  run rpc_post_result "$NODE_ADDR" "$payload"
  [ "$status" -eq 0 ]
  [ "$output" = "0x0000000000000000000000000000000000000000000000000000000000000000" ]
  
}