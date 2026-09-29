# Reproducible evaluation plan

## Research questions

1. What gas and prover-time premium does knowledge proof registration add over plain commit/reveal?
2. Does pre-registration proof of knowledge prevent any concrete griefing trace that simple binding commitments do not already prevent?
3. Under independently sampled non-reveal rates and strategically withheld reveals, how do threshold, participant count, abort rate, and outcome choice change?

The second question is intentionally skeptical: ordinary commitments plus a binding preimage check may already solve the relevant problem. A null result is a useful outcome.

## Baselines

| Variant | Registration | Reveal | External trust |
| --- | --- | --- | --- |
| Proposed | Poseidon + Groth16 knowledge proof | Poseidon preimage | Circuit, setup, verifier, block proposer assumptions |
| Plain commit/reveal | Keccak commitment | Keccak preimage | Block proposer assumptions |
| Block seed only | No registration | No reveal | Block proposer assumptions |
| External VRF | Request and callback | No user reveal | Oracle network and subscription model |

Use one chain configuration and explicitly state what is and is not comparable. Do not claim equal security across these variants.

## Measurements to collect

- Compiler versions, optimization settings, circuit constraint count, setup provenance, verification key hash, machine CPU/RAM, and git revision.
- Median, p95, and range of witness generation and proof creation over at least 30 runs, separately from setup.
- Deployment gas for verifier and Poseidon; gas for `createRound`, `register`, `lockSeed`, `reveal`, `finalize`, and `abortExpired` at varied participant counts.
- Output consistency between circuit witness, JS Poseidon, and deployed EVM Poseidon, including edge cases 0, 1, and field modulus minus 1.
- Monte Carlo abort fractions with declared non-reveal distributions; adversarial simulations where the last participant sees others' reveals and decides whether to reveal based on one output bit.
- Sensitivity to thresholds 1, half, and all participants, and to gas price assumptions (report gas units independently of currency).

Do not report unrun experiments as findings. The included Python model illustrates order invariance and withholding, not Ethereum gas, Groth16 proof validity, or a statistical security result.

## Acceptance criteria for a paper artifact

The release should include a pinned setup transcript, verifier source, reproducible dependencies and scripts, test vectors crossing circuit and EVM, contract tests against real cryptographic endpoints, machine-readable raw measurements, analysis notebooks, and a security review. The current repository is a proposal/prototype until those items are completed.
