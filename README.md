# ZK-assisted randomness beacon for Ethereum

Research prototype of an epoch-based, permissionless commit/reveal beacon. A Groth16 proof shows that a participant knows the secret behind a Poseidon commitment **without disclosing that secret during registration**. An Ethereum block hash is captured after registration closes. Participants then disclose their secrets, and the contract checks each disclosure against its original commitment.

This is a research artifact, **not an audited production beacon or an EIP**. The main question is whether adding a zero-knowledge proof of knowledge to registration changes participation, gas cost, and failure behavior enough to justify its prover and verifier overhead. The proof does not eliminate last-revealer withholding.

## Contents

- [Protocol and threat model](docs/protocol.md)
- [Research questions and evaluation](docs/evaluation.md)
- [Reconstructed June 2025–May 2026 chronology](docs/research-chronology.md)
- [Deployment and proof generation](docs/reproducibility.md)
- [Contract](src/ZKRandomnessBeacon.sol), [circuit](circuits/KnowledgeOfSecret.circom), [Foundry tests](test/ZKRandomnessBeacon.t.sol)

## Protocol at a glance

For round `r`, a participant `a` samples a secret field element `s` and computes
`C = Poseidon(s, r, uint160(a))`. The circuit proves knowledge of `s` for the public inputs `[C, r, uint160(a)]`. An accepted proof registers `C` during the commit phase. After the phase closes, anyone may lock the round with `blockhash(commitEnd)` while that hash is still accessible. Registered participants disclose `s` during the reveal phase. The contract calls the **same Poseidon parameterization** to verify `C`; each valid secret is XORed into a 32-byte accumulator. If enough participants reveal, the output is

```text
keccak256(abi.encode(
  "ZK_BEACON_V1", block.chainid, address(this), roundId,
  seedBlockHash, xorOfSecrets, revealCount
))
```

The output is only released after the reveal phase. Withholding a reveal can alter or abort the outcome. No claim of unbiasability, unpredictability after registration, or economic security is made.

## Quick start

Requires Foundry for contracts and tests. The circuit and proof generation additionally require Circom 2, Node.js, `circomlib`, `circomlibjs`, and `snarkjs`. See [reproducibility](docs/reproducibility.md) for a full ceremony and deployment workflow.

```sh
forge test -vv
python3 -m unittest discover -s model -p 'test_*.py'
```

The Foundry suite uses mock cryptographic endpoints to test the state machine. A separate real-proof integration run is required before deploying with a real verifier. No real-proof test or gas measurement is claimed here.

## Scope

Ethereum mainnet-compatible EVM semantics are assumed. Each round has bounded participants, a minimum reveal count, and a capture window for the block hash. The owner schedules rounds; the registration, locking, revealing, and finalization steps are open to any eligible caller. There is no bond, slashing, fee, or upgrade path. The owner cannot change the immutable proof verifier or Poseidon contract.

## References

- [EIP-4399: PREVRANDAO](https://eips.ethereum.org/EIPS/eip-4399)
- [EIP-4788: Beacon block root in the EVM](https://eips.ethereum.org/EIPS/eip-4788)
- [Circom 2 documentation](https://docs.circom.io/)
- [Circomlib Poseidon circuit](https://github.com/iden3/circomlib/blob/master/circuits/poseidon.circom)
- [Chainlink VRF security considerations](https://docs.chain.link/vrf/v2-5/security)

Apache-2.0 licensed. Contributions and independent replication are welcome.
