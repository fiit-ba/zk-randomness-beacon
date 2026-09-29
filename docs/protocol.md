# Protocol, assumptions, and threats

## State machine

1. The owner creates round `r` with `commitEnd`, `maxParticipants ≤ 64`, and `1 ≤ minReveals ≤ maxParticipants`.
2. During registration, each address submits one Poseidon commitment and a Groth16 proof of knowledge of its secret, bound to `r` and `msg.sender`. The secret must be sampled uniformly from the BN254 scalar field; low-entropy secrets can be guessed from public commitments.
3. The last registration block is `commitEnd`. In a later block, within the 256-block `BLOCKHASH` window, anyone calls `lockSeed`; the contract saves `blockhash(commitEnd)`. The seed is fixed by the chosen block number, not chosen by the locking caller. A missed window aborts the round.
4. Until `revealEnd`, registered addresses disclose their field elements. The contract recomputes `Poseidon(secret, r, address)` and accepts at most one matching reveal per address.
5. After `revealEnd`, anyone finalizes. Fewer than `minReveals` means abort. Otherwise a domain-separated Keccak hash combines the block hash, XOR of valid revealed secrets, count, chain ID, contract, and round.

The generated Poseidon contract and Circom library **must use the same parameters and release**. The verifier must be generated from the precise circuit and trusted setup used by the prover. Any verifier/Poseidon address supplied at construction is permanently trusted; deploying arbitrary or mock contracts defeats the intended checks.

## Security properties and limits

| Property | Assessment |
| --- | --- |
| Commitment binding | Depends on Poseidon collision resistance and consistent circuit/contract parameters. |
| Secret knowledge at registration | Depends on Groth16 soundness, correct verification key, and a secure setup. The contract checks public inputs against the round and caller. |
| Secret privacy before reveal | Groth16 hides the witness under its assumptions, but the public commitment does not hide a weak secret against guessing. The reveal is permanently public. |
| Block seed scheduling | The registration deadline fixes the target block. A block proposer has some influence over its block hash, including transaction selection and withholding/reorganization incentives. It is not a VRF. |
| Outcome bias | A participant who can evaluate the seed and others' reveals can decide to reveal or withhold. XOR is order independent but does **not** prevent this last-revealer attack. Multiple colluding accounts amplify choices. |
| Liveness | Anyone may lock or finalize. A missed lock window aborts. Fewer than the threshold reveals aborts. There is no slashing or fallback. |
| Sybil resistance | One commitment per address per round; addresses are cheap. No identity or stake requirement. |
| Timing | Seed is public before reveals. Transaction ordering can affect whether a reveal lands before the deadline. A reorganization can change the seed until chain finality; applications should wait for appropriate finality before acting. |
| On-chain proof validation | A valid proof is necessary at registration; revealing alone does not prove honest participation. Neither a valid proof nor a large participant count establishes unbiased output. |

For high-value applications, analyze a threshold VRF, distributed key generation, penalties for withholding, or an established audited oracle separately. Penalties also require an explicit economic model and do not create perfect bias resistance. Consumers should check `status == Finalized`, wait for finality, and bind each request to its `roundId`.

## Alternatives and baselines

- `PREVRANDAO` (EIP-4399) exposes consensus randomness, with proposer influence and timing caveats. It avoids per-user ZK proofs.
- EIP-4788 exposes beacon block roots, not a turnkey unbiased random number. Extracting a consensus state field requires additional proof/verification machinery.
- A verifiable random function service offers a different trust, liveness, and fee model. Compare request confirmation, operator trust, and callback behavior explicitly.
- A plain commit/reveal beacon removes the ZK proof but retains reveal withholding. This is the primary baseline for measuring whether proof of knowledge brings value.

## Non-goals

No claim of formal proof of security, production readiness, decentralized setup, manipulation-free entropy, or equivalence to Ethereum's consensus RANDAO. No mainnet deployment has been performed.
