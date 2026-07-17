# GravArc Circuits — Compiled Artifacts & Phase-2 Trusted Setup Ceremony

This repository holds the **compiled Groth16 proving keys** (`*_final.zkey`) and
WASM witness generators (`*_js/`) for the GravArc privacy circuits, and hosts an
**open, append-only phase-2 trusted-setup ceremony** for them.

If you use GravArc to hold funds, the soundness of the ZK proofs depends on this
ceremony. Anyone is invited to contribute — **the more independent contributors,
the less anyone has to trust the deployer.**

## Circuits

Ten circuits: a deposit and a withdraw circuit for each of five receiver tiers.

| circuit | role | receiver tier |
|---|---|---|
| `deposit_8` … `deposit_128`   | deposit  | 8, 16, 32, 64, 128 |
| `withdraw_8` … `withdraw_128` | withdraw | 8, 16, 32, 64, 128 |

Source circuits (`.circom`) and the on-chain contracts live in the main GravArc
repository: `<SOURCE_REPO_URL>`.

---

## Why a ceremony? (the trust model)

A Groth16 setup has two phases, protecting **independent** secrets:

- **Phase 1 — Powers of Tau (universal).** Secures `τ, α, β`. We use
  `pot19_final.ptau` from the
  [Perpetual Powers of Tau](https://github.com/privacy-ethereum/perpetualpowersoftau),
  a large many-contributor ceremony. **Trustless. ✅**
- **Phase 2 — circuit-specific.** Samples a new secret `δ` and builds the proving
  key. **Whoever knows `δ` can forge proofs for arbitrary inputs** — i.e. withdraw
  funds they never deposited. A strong phase 1 does *not* help here; `δ` is separate.

Each phase is secure under a **1-of-N** assumption: it is sound as long as *at
least one* contributor in that phase destroyed their secret. Phase 1 already has
many contributors. **This ceremony is how phase 2 gets more than one.**

> **Current trust statement.** Phase 1 is the trustless Perpetual Powers of Tau.
> The genesis phase-2 contribution (`attestations/001-deployer-genesis.md`) was
> made by the deployer alone, so until others contribute you are trusting that the
> deployer destroyed `δ`. **Every additional contributor removes that trust:** once
> one *other* honest party participates, no single party — including the deployer —
> can forge proofs.

---

## How to contribute (≈5 minutes)

You need [Node.js](https://nodejs.org) and snarkjs:

```bash
npm install -g snarkjs
```

Then:

```bash
# 1. Fork this repo on GitHub, then clone YOUR fork
git clone git@github.com:<you>/pact-circuits-compiled.git
cd pact-circuits-compiled

# 2. (Recommended) verify the current chain before adding to it — see "Verify" below

# 3. Contribute. This mixes fresh randomness from YOUR machine into all 10 circuits
#    and advances the *_final.zkey files in place.
./scripts/contribute.sh "your-name-or-github-handle"

# 4. Commit and open a PR
git add -A
git commit -m "phase2 contribution NNN: your-handle"
git push
# open a Pull Request against this repository
```

What the script does: for each circuit it runs `snarkjs zkey contribute`, drawing
64 bytes of entropy from your OS CSPRNG, and writes a small attestation file under
`attestations/` recording your contribution hashes. **Your entropy never leaves
your machine and is discarded** — that is exactly the "toxic waste" you are
expected to destroy.

> Want to stir in keyboard randomness too? Edit `scripts/contribute.sh` and remove
> the `-e="$ENTROPY"` flag; snarkjs will then prompt you to type random text for
> each circuit.

### The ceremony is sequential

Phase-2 contributions form a linear chain — each one builds on the previous head.
**Only one PR can be merged at a time**, and the next contributor must start from
the newly merged state. Please coordinate via the pinned issue / wait for your PR
to merge before others begin. If your fork falls behind, re-clone the latest main
and re-run the script.

---

## Verify (don't trust — check)

Anyone can verify that the published zkeys are a valid chain of contributions on
the correct circuits and the correct phase-1 ptau:

```bash
# r1cs: rebuild from the source circuits (one .r1cs per circuit), e.g.
#   circom circuits/deposit_8.circom --r1cs -o build   # for all 10 circuits
# ptau: download pot19_final.ptau from Perpetual Powers of Tau and check its hash
#   against the value below.

R1CS_DIR=/path/to/r1cs  PTAU=/path/to/pot19_final.ptau  ./scripts/verify.sh
```

`snarkjs zkey verify` prints **every contribution hash, in order**, for each
circuit. To confirm a specific contribution is included, match the hashes in its
`attestations/NNN-*.md` file against that list.

- **Phase-1 ptau:** `pot19_final.ptau` — Blake2b hash `<POT19_HASH>` *(fill in and
  keep this value; it pins the exact phase-1 file the ceremony is built on)*.

---

## Finalization (maintainer)

When enough contributions have been collected, the maintainer closes the ceremony
with a **public random beacon** and exports the verifiers:

```bash
BEACON=<public-randomness-hex>  ITERS=10  ./scripts/finalize.sh
```

Choose a beacon value that did not exist when the last contribution was made (e.g.
a specific future Ethereum block hash, announced in advance) so no contributor can
grind against it. This produces:

- `final/<circuit>_final.zkey` — beacon-finalized proving keys
- `verifiers/<circuit>_vkey.json` — verification keys
- `verifiers/<Name>Verifier_N.sol` — Solidity verifiers to deploy

After finalization the maintainer promotes `final/*_final.zkey` to the repo root,
deploys the verifier contracts, and publishes the beacon value + source so users
can re-derive and check the deployed verifier bytecode.

---

## Generate the artifact manifest (maintainer)

The application uses `manifest.json` to identify the exact WASM and proving-key
files served from this repository. Generate it here—not in the source-circuit
build directory—so its hashes describe the final artifacts after copying,
contributions, or beacon finalization.

Run the generator manually from the repository root:

```bash
cd /path/to/gravarc-compiled
node scripts/generate-manifest.mjs
```

The generator:

- requires all deposit, withdraw, and refund artifacts for tiers 8, 16, 32, 64,
  and 128;
- hashes 15 WASM files and 15 zkey files with SHA-256;
- records each artifact's relative path and byte size;
- derives a stable `bundleVersion` from the complete artifact set; and
- writes `manifest.json` atomically, so readers never see a partial manifest.

Successful output looks like:

```text
Generated manifest.json for 30 artifacts
Bundle version: <64-character SHA-256 value>
```

Run the generator again whenever a served WASM or zkey changes, including after:

1. copying newly compiled artifacts from the source repository;
2. accepting a phase-2 contribution that updates zkeys;
3. promoting beacon-finalized proving keys; or
4. manually replacing an artifact.

Generate the manifest only after all artifact updates are complete, then commit
`manifest.json` together with the corresponding artifacts. If the files have not
changed, `bundleVersion` remains the same; `generatedAt` records when the manifest
was refreshed.

---

## Repository layout

```
deposit_<N>_final.zkey      proving key (current ceremony head)
withdraw_<N>_final.zkey
deposit_<N>_js/             WASM witness generator
withdraw_<N>_js/
attestations/               one markdown file per contribution (the transcript)
scripts/contribute.sh       add one contribution
scripts/verify.sh           verify the chain against r1cs + ptau
scripts/finalize.sh         maintainer: beacon + export verifiers
scripts/lib.sh              shared definitions
scripts/generate-manifest.mjs
                            hash served artifacts and write manifest.json
manifest.json               generated artifact metadata consumed by the application
```

> **Note on size.** zkeys are large (the biggest is ~80 MB) and each contribution
> replaces them, so git history grows by roughly the full set per contribution.
> For a small invited ceremony this is acceptable; for a large public one consider
> Git LFS or a coordinator that stores only attestations in git.

---

## Security checklist for contributors

- [ ] Run on a machine you trust; the OS CSPRNG provides the entropy.
- [ ] Do **not** record, log, or share the random entropy — let it be discarded.
- [ ] Verify the chain before and/or after your contribution.
- [ ] Keep your attestation file in your PR so your contribution is auditable.
