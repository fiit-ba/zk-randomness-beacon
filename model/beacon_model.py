"""Small independent state model for phase and withholding experiments.

This is not an implementation of Poseidon, Groth16, or the EVM.
"""

from dataclasses import dataclass, field
from hashlib import sha3_256


@dataclass
class BeaconModel:
    min_reveals: int
    registered: dict[str, int] = field(default_factory=dict)
    revealed: dict[str, int] = field(default_factory=dict)

    def register(self, participant: str, secret: int) -> None:
        if participant in self.registered:
            raise ValueError("duplicate")
        self.registered[participant] = secret

    def reveal(self, participant: str, secret: int) -> None:
        if self.registered.get(participant) != secret or participant in self.revealed:
            raise ValueError("invalid reveal")
        self.revealed[participant] = secret

    def finalize(self, seed: bytes) -> bytes | None:
        if len(self.revealed) < self.min_reveals:
            return None
        xor = 0
        for secret in self.revealed.values():
            xor ^= secret
        return sha3_256(seed + xor.to_bytes(32, "big")
                        + len(self.revealed).to_bytes(2, "big")).digest()
