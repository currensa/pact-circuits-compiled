#!/usr/bin/env bash
#
# Verify the current head zkeys against the circuit constraints (.r1cs) and the
# phase-1 Powers of Tau (.ptau). `snarkjs zkey verify` confirms that each zkey is
# a valid chain of phase-2 contributions on top of that exact circuit and ptau,
# and prints every contribution hash in order — so anyone can check that the
# hashes recorded in attestations/ actually appear in the chain.
#
# You need:
#   - the .r1cs files (one per circuit). Rebuild them from the source circuits:
#       cd <pact source repo> && circom circuits/deposit_8.circom --r1cs -o build
#     or obtain them from the source repo's build artifacts.
#   - pot19_final.ptau from the Perpetual Powers of Tau ceremony
#     (https://github.com/privacy-ethereum/perpetualpowersoftau). Verify its hash
#     against the value published in README.md before trusting it.
#
# Usage:
#   R1CS_DIR=/path/to/r1cs PTAU=/path/to/pot19_final.ptau ./scripts/verify.sh
#
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
cd "$REPO_ROOT"

: "${PTAU:?Set PTAU=/path/to/pot19_final.ptau}"
: "${R1CS_DIR:?Set R1CS_DIR=/path/to/dir/containing/<circuit>.r1cs}"
require_snarkjs

[ -f "$PTAU" ] || { echo "ERROR: PTAU not found: $PTAU" >&2; exit 1; }

fail=0
for c in $CIRCUITS; do
  R1CS="$R1CS_DIR/${c}.r1cs"
  ZKEY="${c}_final.zkey"
  echo "=================================================================="
  echo "Verifying ${c}"
  echo "=================================================================="
  [ -f "$R1CS" ] || { echo "ERROR: missing $R1CS" >&2; fail=1; continue; }
  [ -f "$ZKEY" ] || { echo "ERROR: missing $ZKEY" >&2; fail=1; continue; }
  if ! snarkjs zkey verify "$R1CS" "$PTAU" "$ZKEY"; then
    echo "✗ ${c}: ZKEY VERIFICATION FAILED" >&2
    fail=1
  fi
done

echo
if [ "$fail" -ne 0 ]; then
  echo "✗ One or more circuits failed verification." >&2
  exit 1
fi
echo "✓ All zkeys verified. Compare the printed contribution hashes against attestations/."
