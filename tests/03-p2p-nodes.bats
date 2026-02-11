#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

load "helpers.bash"

setup() {
  NODE1_URL="http://p2p-node-1:8545"
  NODE2_URL="http://p2p-node-2:8545"
  
  wait_rpc "$NODE1_URL"
  wait_rpc "$NODE2_URL"
}

@test "Nodes are running on dev network (id 2018)" {
  run -0 net_version "$NODE1_URL"
  [ "$output" = "2018" ]
  
  run -0 net_version "$NODE2_URL"
  [ "$output" = "2018" ]
}

@test "Node 1 advertises the correct static IP in enode URL" {
  local payload='{"jsonrpc":"2.0","method":"admin_nodeInfo","params":[],"id":1}'
  local enode=""

  for i in {1..5}; do
    run rpc_post_result "$NODE1_URL" "$payload"

    enode="$(printf '%s' "$output" | jq -r 'try .enode // empty' 2>/dev/null)" || true
    if [ -n "$enode" ]; then
      break
    fi

    sleep 1
  done

  [[ "$enode" == *"@172.28.0.5:30303"* ]]
}

@test "Nodes correctly find each other (P2P connection)" {
  local info_payload='{"jsonrpc":"2.0","method":"admin_nodeInfo","params":[],"id":1}'
  enode1=$(rpc_post_result "$NODE1_URL" "$info_payload" | jq -r '.enode')
  
  local add_payload
  add_payload=$(jq -n --arg enode "$enode1" '{"jsonrpc":"2.0","method":"admin_addPeer","params":[$enode],"id":1}')
  
  run rpc_post_result "$NODE2_URL" "$add_payload"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
  
  connected=false
  for i in {1..30}; do
    cnt1=$(net_peerCount "$NODE1_URL")
    cnt2=$(net_peerCount "$NODE2_URL")  
    if [ "$cnt1" -ge 1 ] && [ "$cnt2" -ge 1 ]; then
      connected=true
      break
    fi
    sleep 1
  done
  
  [ "$connected" = "true" ]
}
