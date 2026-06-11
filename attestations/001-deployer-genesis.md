# Contribution 001 — deployer (genesis)

This is the genesis phase-2 contribution that produced the initial `*_final.zkey`
files in this repository. It was made with snarkjs `zkey contribute` on top of
the phase-1 `pot19_final.ptau` from the Perpetual Powers of Tau ceremony.

At this point the ceremony rests on a **single** contributor having destroyed
their phase-2 secret `δ`. Public contributions (002, 003, …) build on top of this
to remove that single point of trust: once at least one *other* honest
contributor participates, no single party — including the deployer — can forge
proofs.

To confirm this contribution is part of the chain, run `./scripts/verify.sh`; it
lists every contribution hash for each circuit in order, and contribution #1 is
this genesis contribution.
