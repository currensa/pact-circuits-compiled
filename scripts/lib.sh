#!/usr/bin/env bash
# Shared definitions for the GravArc phase-2 ceremony scripts.

# The 10 circuits in this ceremony (deposit/withdraw × 5 receiver tiers).
CIRCUITS="deposit_8 deposit_16 deposit_32 deposit_64 deposit_128 \
withdraw_8 withdraw_16 withdraw_32 withdraw_64 withdraw_128"

# Repository root (parent of scripts/).
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Solidity contract name for a circuit, e.g. deposit_8 -> DepositVerifier_8.
contract_name() {
  local c="$1" side num head
  side="${c%%_*}"          # deposit | withdraw
  num="${c##*_}"           # 8 | 16 | ...
  head="$(printf '%s' "${side:0:1}" | tr '[:lower:]' '[:upper:]')${side:1}"
  printf '%sVerifier_%s' "$head" "$num"
}

require_snarkjs() {
  command -v snarkjs >/dev/null 2>&1 || {
    echo "ERROR: snarkjs not found. Install it with: npm install -g snarkjs" >&2
    exit 1
  }
}
