#!/bin/bash

login() {
  local url="${1:-}"
  local user="${2:-}"
  local pass="${3:-}"
  local connect_timeout="${4:-3}"
  local max_time="${5:-10}"

  if [ -z "$url" ] || [ -z "$user" ] || [ -z "$pass" ]; then
    printf 'Usage: login_jwt <url> <user> <pass> [connect_timeout] [max_time]\n' >&2
    return 2
  fi

  local login_payload
  login_payload="$(jq -n --arg u "$user" --arg p "$pass" '{username: $u, password: $p}')"
  
  local resp
  if ! resp="$(curl -sS --fail-with-body \
    --connect-timeout "$connect_timeout" \
    --max-time "$max_time" \
    -H 'Content-Type: application/json' \
    --data-raw "$login_payload" \
    "${url}/login" 2> >(sed 's/^/curl: /' >&2))"; then
    return $?
  fi

  local token
  token="$(printf '%s\n' "$resp" | jq -r '.token // empty')"
  if [ -z "$token" ]; then
    printf 'No token in login response\n' >&2
    return 1
  fi

  printf '%s\n' "$token"
}

rpc_post() {
  local url="${1:-}"
  local payload="${2:-}"
  local token="${3:-}"
  local connect_timeout="${4:-3}"
  local max_time="${5:-10}"

  if [ -z "$url" ] || [ -z "$payload" ]; then
    printf 'Usage: rpc_post <http(s)://host:port> <json-payload> [token] [connect_timeout] [max_time]\n' >&2
    return 2
  fi

  local -a curl_args=(
    -sS --fail-with-body
    --connect-timeout "$connect_timeout"
    --max-time "$max_time"
    -H 'Content-Type: application/json'
  )

  if [ -n "$token" ]; then
    curl_args+=(-H "Authorization: Bearer ${token}")
  fi

  curl "${curl_args[@]}" \
    --data-raw "$payload" \
    "$url" 2> >(sed 's/^/curl: /' >&2)
}

rpc_post_error() {
  local url="${1:-}"
  local payload="${2:-}"
  local token="${3:-}"
  local connect_timeout="${4:-3}"
  local max_time="${5:-10}"

  local resp
  if ! resp="$(rpc_post "$url" "$payload" "$token" "$connect_timeout" "$max_time")"; then
    local status=$?
    return "$status"
  fi

  local jrpc_msg
  jrpc_msg="$(printf '%s\n' "$resp" | jq -r 'try .error.message // empty')" || true
  if [ -n "$jrpc_msg" ]; then
    printf 'RPC error: %s\n' "$jrpc_msg" >&2
    return 1
  fi

  printf '%s\n' "$resp"
}

rpc_post_result() {
  local url="${1:-}"
  local payload="${2:-}"
  local token="${3:-}"
  local connect_timeout="${4:-3}"
  local max_time="${5:-10}"

  local resp
  if ! resp="$(rpc_post_error "$url" "$payload" "$token" "$connect_timeout" "$max_time")"; then
    return $?
  fi
  if ! printf '%s\n' "$resp" | jq -e 'has("result")' >/dev/null; then
    printf 'Missing result in response\n' >&2
    return 1
  fi
  local res
  res="$(printf '%s\n' "$resp" | jq -r '.result')"
  if [ "$res" = "null" ] || [ -z "$res" ]; then
    printf 'Null result in response\n' >&2
    return 1
  fi
  printf '%s\n' "$res"
}

eth_chainId() {
  local url="${1:-}"
  local token="${2:-}"
  local payload='{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
  local result
  result="$(rpc_post_result "$url" "$payload" "$token")"

  local clean="${result#0x}"
  if ! [[ "$clean" =~ ^[0-9a-fA-F]+$ ]]; then
    printf 'Invalid chainId format: %s\n' "$result" >&2
    return 1
  fi
  printf '%d\n' "$((16#$clean))"
}

net_version() {
  local url="${1:-}"
  local token="${2:-}"
  local payload='{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}'
  local result
  result="$(rpc_post_result "$url" "$payload" "$token")"

  if ! [[ "$result" =~ ^[0-9]+$ ]]; then
    printf 'Invalid network id format: %s\n' "$result" >&2
    return 1
  fi
  printf '%d\n' "$result"
}

eth_blockNumber() {
  local url="${1:-}"
  local token="${2:-}"
  local payload='{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
  local result
  result="$(rpc_post_result "$url" "$payload" "$token")"

  local clean="${result#0x}"
  if [ -z "$clean" ] || ! [[ "$clean" =~ ^[0-9a-fA-F]+$ ]]; then
    printf 'Invalid block number format: %s\n' "$result" >&2
    return 1
  fi
  printf '%d\n' "$((16#$clean))"
}

eth_syncing() {
  local url="${1:-}"
  local token="${2:-}"
  local payload='{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}'
  local result
  result="$(rpc_post_result "$url" "$payload" "$token")"

  if [ "$result" = "false" ]; then
    printf 'false\n'
    return 0
  fi
  if ! printf '%s' "$result" | jq -e . >/dev/null 2>&1; then
    printf 'Invalid eth_syncing response: %s\n' "$result" >&2
    return 1
  fi
  printf '%s\n' "$result"
}

net_peerCount() {
  local url="${1:-}"
  local token="${2:-}"
  local payload='{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}'
  local result
  result="$(rpc_post_result "$url" "$payload" "$token")"

  local clean="${result#0x}"
  if [ -z "$clean" ] || ! [[ "$clean" =~ ^[0-9a-fA-F]+$ ]]; then
    printf 'Invalid peer count format: %s\n' "$result" >&2
    return 1
  fi
  printf '%d\n' "$((16#$clean))"
}

wait_rpc() {
  local url="${1:-}"
  local token="${2:-}"

  if [ -z "$url" ]; then
    printf 'Usage: wait_rpc <http(s)://host:port> [token]\n' >&2
    return 2
  fi

  local payload='{"jsonrpc":"2.0","method":"web3_clientVersion","params":[],"id":1}'

  for i in {1..10}; do
    local -a curl_args=(
      -sS
      -o /dev/null
      -w '%{http_code}'
      --connect-timeout 1
      --max-time 2
      -H 'Content-Type: application/json'
      --data-raw "$payload"
    )

    if [ -n "$token" ]; then
      curl_args+=(-H "Authorization: Bearer ${token}")
    fi

    local code
    if ! code="$(curl "${curl_args[@]}" "$url" || true)"; then
      printf "Attempt %d/30 failed to execute curl.\n" "$i" >&2
    fi

    if [ -n "$code" ] && [ "$code" != "000" ]; then
      return 0
    fi
    sleep 1
  done

  return 1
}

