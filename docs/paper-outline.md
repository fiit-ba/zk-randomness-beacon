# Manuscript outline

**Working title:** On the Utility and Limits of Zero-Knowledge Proofs of Knowledge in Ethereum Commit/Reveal Randomness Beacons

## Claim to test

A registration-time proof of knowledge can prevent commitments for which the submitter does not know a valid opening, while revealing the secret only after a fixed future block. The practical value of that property, compared with cheaper plain commitments, is an empirical question. It does not solve selective non-reveal.

## Suggested structure

1. **Problem and threat model:** on-chain games, selection, asynchronous participation, block proposers, rational and colluding participants.
2. **Related work:** Ethereum RANDAO/PREVRANDAO, commit/reveal, VRFs, threshold beacons, ZK knowledge proofs, and withholding incentives.
3. **Protocol:** exact statement, public inputs, state machine, entropy source, abort rules, and consumer API.
4. **Security analysis:** commitment and proof assumptions; mempool copying; sybil behavior; last-revealer bias; liveness; reorgs.
5. **Implementation:** Circom, Groth16, Poseidon, Solidity, setup and reproducibility.
6. **Evaluation:** reproducible gas and proving benchmarks, model simulations, and plain commit/reveal baseline.
7. **Discussion:** whether added proof cost achieves a distinct property, deployment tradeoffs, and limits.

## Evidence needed before submission

Real cryptographic integration tests, independent review of circuit/on-chain hash parity, trustworthy setup transcript, raw performance measurements, and a formalized adversarial strategy. Do not turn the timeline in this repository into a claim of experiments completed during 2025–2026.
