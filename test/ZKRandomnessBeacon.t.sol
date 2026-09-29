// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "../src/ZKRandomnessBeacon.sol";

interface Vm {
    function roll(uint256 newBlockNumber) external;
    function setBlockhash(uint256 blockNumber, bytes32 blockHash) external;
    function prank(address sender) external;
    function expectRevert(bytes4 selector) external;
}

contract MockPoseidon is IPoseidon3 {
    function poseidon(uint256[3] calldata inputs) external pure returns (uint256) {
        return uint256(keccak256(abi.encode(inputs))) %
            21888242871839275222246405745257275088696311157297823662689037894645226208583;
    }
}

contract MockVerifier is IKnowledgeVerifier {
    bool public allow = true;
    function setAllow(bool value) external { allow = value; }
    function verifyProof(
        uint256[2] calldata,
        uint256[2][2] calldata,
        uint256[2] calldata,
        uint256[3] calldata
    ) external view returns (bool) { return allow; }
}

contract ZKRandomnessBeaconTest {
    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address constant ALICE = address(0xA11CE);
    address constant BOB = address(0xB0B);
    MockPoseidon poseidon;
    MockVerifier verifier;
    ZKRandomnessBeacon beacon;

    function setUp() public {
        vm.roll(1000);
        poseidon = new MockPoseidon();
        verifier = new MockVerifier();
        beacon = new ZKRandomnessBeacon(address(verifier), address(poseidon));
    }

    function _proofA() internal pure returns (uint256[2] memory) { return [uint256(0), 0]; }
    function _proofB() internal pure returns (uint256[2][2] memory) {
        return [[uint256(0), 0], [uint256(0), 0]];
    }

    function _register(uint256 id, address participant, uint256 secret) internal {
        uint256[3] memory preimage = [secret, id, uint256(uint160(participant))];
        uint256 commitment = poseidon.poseidon(preimage);
        vm.prank(participant);
        beacon.register(id, commitment, _proofA(), _proofB(), _proofA());
    }

    function testHappyPathAndReplayProtection() public {
        uint256 id = beacon.createRound(1005, 2, 2);
        _register(id, ALICE, 17);
        _register(id, BOB, 23);
        vm.prank(ALICE);
        vm.expectRevert(ZKRandomnessBeacon.AlreadyCommitted.selector);
        beacon.register(id, 12, _proofA(), _proofB(), _proofA());

        vm.roll(1006);
        vm.setBlockhash(1005, bytes32(uint256(0xBEEF)));
        beacon.lockSeed(id, 10);
        vm.prank(ALICE);
        beacon.reveal(id, 17);
        vm.prank(BOB);
        beacon.reveal(id, 23);
        vm.prank(ALICE);
        vm.expectRevert(ZKRandomnessBeacon.InvalidReveal.selector);
        beacon.reveal(id, 17);

        vm.roll(1017);
        bytes32 result = beacon.finalize(id);
        require(result != bytes32(0), "empty output");
        (,,,,,, ZKRandomnessBeacon.Status status,,,) = beacon.rounds(id);
        require(status == ZKRandomnessBeacon.Status.Finalized, "wrong state");
        vm.expectRevert(ZKRandomnessBeacon.InvalidPhase.selector);
        beacon.finalize(id);
    }

    function testWrongRevealAndAbortedRound() public {
        uint256 id = beacon.createRound(1005, 2, 2);
        _register(id, ALICE, 17);
        vm.roll(1006);
        vm.setBlockhash(1005, bytes32(uint256(0xBEEF)));
        beacon.lockSeed(id, 2);
        vm.prank(ALICE);
        vm.expectRevert(ZKRandomnessBeacon.InvalidReveal.selector);
        beacon.reveal(id, 18);
        vm.prank(ALICE);
        beacon.reveal(id, 17);
        vm.roll(1009);
        require(beacon.finalize(id) == bytes32(0), "should abort");
        (,,,,,, ZKRandomnessBeacon.Status status,,,) = beacon.rounds(id);
        require(status == ZKRandomnessBeacon.Status.Aborted, "wrong state");
    }

    function testInvalidProofAndCapacity() public {
        uint256 id = beacon.createRound(1005, 1, 1);
        verifier.setAllow(false);
        vm.expectRevert(ZKRandomnessBeacon.InvalidProof.selector);
        beacon.register(id, 1, _proofA(), _proofB(), _proofA());
        verifier.setAllow(true);
        _register(id, ALICE, 17);
        vm.prank(BOB);
        vm.expectRevert(ZKRandomnessBeacon.AtCapacity.selector);
        beacon.register(id, 2, _proofA(), _proofB(), _proofA());
    }

    function testSeedExpiryAndRecovery() public {
        uint256 id = beacon.createRound(1005, 1, 1);
        vm.roll(1262);
        vm.expectRevert(ZKRandomnessBeacon.SeedExpired.selector);
        beacon.lockSeed(id, 5);
        beacon.abortExpired(id);
        (,,,,,, ZKRandomnessBeacon.Status status,,,) = beacon.rounds(id);
        require(status == ZKRandomnessBeacon.Status.Aborted, "wrong state");
    }

    function testCannotUseFutureSeedOrRegisterAfterDeadline() public {
        uint256 id = beacon.createRound(1005, 1, 1);
        vm.expectRevert(ZKRandomnessBeacon.InvalidPhase.selector);
        beacon.lockSeed(id, 5);
        vm.roll(1006);
        vm.prank(ALICE);
        vm.expectRevert(ZKRandomnessBeacon.InvalidPhase.selector);
        beacon.register(id, 1, _proofA(), _proofB(), _proofA());
    }
}
