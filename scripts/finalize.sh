#!/usr/bin/env bash
#
# MAINTAINER ONLY — close the ceremony with a public random beacon and export
# the verification keys + Solidity verifiers.
#
# The beacon is applied AFTER all secret contributions. Its value is public by
# design (e.g. a future Ethereum block hash or a drand round): it removes the
# ability of the last contributor to bias/grind the result, while security still
# rests on the earlier secret contributions. Pick a beacon value that did not
# exist when the last contribution was made, and announce it in advance.
#
# Usage:
#   BEACON=<hex>  ITERS=10  ./scripts/finalize.sh
#     BEACON  public randomness as a hex string (no 0x), e.g. an ETH block hash
#     ITERS   number of hash iterations as a power of 2 (default 10)
#
# Outputs:
#   final/<circuit>_final.zkey     beacon-finalized proving keys
#   verifiers/<circuit>_vkey.json  verification keys
#   verifiers/<Name>Verifier_N.sol Solidity verifiers (deploy these)
#
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
cd "$REPO_ROOT"

: "${BEACON:?Set BEACON=<public random beacon hex, no 0x prefix>}"
ITERS="${ITERS:-10}"
require_snarkjs

mkdir -p final verifiers

for c in $CIRCUITS; do
  echo ">> finalizing ${c} (beacon)"
  snarkjs zkey beacon "${c}_final.zkey" "final/${c}_final.zkey" "$BEACON" "$ITERS" -n="Final Beacon"

  echo ">> exporting verification key + verifier for ${c}"
  snarkjs zkey export verificationkey "final/${c}_final.zkey" "verifiers/${c}_vkey.json"

  CNAME="$(contract_name "$c")"
  snarkjs zkey export solidityverifier "final/${c}_final.zkey" "verifiers/_tmp.sol"
  sed "s/contract Groth16Verifier/contract ${CNAME}/" "verifiers/_tmp.sol" > "verifiers/${CNAME}.sol"
  rm -f "verifiers/_tmp.sol"
done

echo
echo "✓ Finalized. Next:"
echo "  - Publish final/ and verifiers/ and the beacon value + source."
echo "  - Promote final/<circuit>_final.zkey to the repo root (replace the head zkeys)."
echo "  - Deploy verifiers/*Verifier_*.sol and verify the on-chain bytecode against them."
