#!/usr/bin/env bash
#
# Add ONE phase-2 contribution on top of the current head zkeys.
#
# Each run mixes fresh local randomness into every circuit's proving key and
# advances the *_final.zkey files in place. Your randomness ("toxic waste") is
# generated on your machine and discarded — the security of the whole ceremony
# holds as long as AT LEAST ONE contributor's randomness stays secret.
#
# Usage:
#   ./scripts/contribute.sh "your-name-or-github-handle"
#
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
cd "$REPO_ROOT"

HANDLE="${1:-}"
if [ -z "$HANDLE" ]; then
  echo "Usage: ./scripts/contribute.sh \"<your-name-or-github-handle>\"" >&2
  exit 1
fi
require_snarkjs

mkdir -p attestations
COUNT="$(find attestations -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')"
IDX="$(printf '%03d' "$((COUNT + 1))")"
SAFE_HANDLE="$(printf '%s' "$HANDLE" | tr -cs 'A-Za-z0-9_.-' '-')"
ATT="attestations/${IDX}-${SAFE_HANDLE}.md"

{
  echo "# Contribution ${IDX} — ${HANDLE}"
  echo
  echo "- Date (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "- snarkjs: $(snarkjs --version 2>/dev/null | tail -1)"
  echo
  echo "Contribution hashes (verifiable later with \`./scripts/verify.sh\`):"
  echo
} > "$ATT"

for c in $CIRCUITS; do
  IN="${c}_final.zkey"
  TMP="${c}.contrib.zkey"
  [ -f "$IN" ] || { echo "ERROR: missing $IN — run from a full clone of the ceremony repo." >&2; exit 1; }

  echo ">> contributing to ${c} ..."

  # Fresh entropy from the OS CSPRNG. If you want to also stir in keyboard
  # randomness, drop the -e flag below and snarkjs will prompt you per circuit.
  ENTROPY="$(head -c 64 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  OUT="$(snarkjs zkey contribute "$IN" "$TMP" --name="${IDX}-${HANDLE}" -v -e="$ENTROPY" 2>&1)"
  unset ENTROPY

  # Capture the 4-line contribution hash snarkjs prints, for the attestation.
  HASH_BLOCK="$(printf '%s\n' "$OUT" | awk '
    tolower($0) ~ /contribution hash/ { grab=4; next }
    grab>0 { gsub(/^[ \t]+/,""); print; grab-- }')"

  mv -f "$TMP" "$IN"

  {
    echo "### ${c}"
    echo '```'
    printf '%s\n' "$HASH_BLOCK"
    echo '```'
    echo
  } >> "$ATT"
done

echo
echo "✓ Done. Advanced all *_final.zkey and wrote $ATT"
echo
echo "Next steps:"
echo "  1. git add -A && git commit -m \"phase2 contribution ${IDX}: ${HANDLE}\""
echo "  2. Open a PR against the ceremony repo."
echo "  3. The ceremony is SEQUENTIAL — your PR must be merged before the next"
echo "     contributor starts. Watch the repo / coordination issue for your turn."
