// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

/// @dev Wrapper around the generated circomlibjs Poseidon(3) bytecode.
interface IPoseidon3 {
    function poseidon(uint256[3] calldata inputs) external view returns (uint256);
}

/// @dev Adapter for the snarkjs-generated Groth16 verifier.
interface IKnowledgeVerifier {
    function verifyProof(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[3] calldata publicSignals
    ) external view returns (bool);
}

/// @title ZK-assisted commit/reveal randomness beacon (research prototype)
/// @notice Security limitations are described in docs/protocol.md.
contract ZKRandomnessBeacon {
    uint256 public constant FIELD_MODULUS =
        21888242871839275222246405745257275088696311157297823662689037894645226208583;
    uint256 public constant MAX_PARTICIPANTS = 64;
    uint256 public constant MAX_REVEAL_BLOCKS = 4096;

    enum Status { Unset, Committing, Revealing, Finalized, Aborted }

    struct Round {
        uint64 commitEnd;
        uint64 revealEnd;
        uint16 maxParticipants;
        uint16 minReveals;
        uint16 commits;
        uint16 reveals;
        Status status;
        bytes32 seedBlockHash;
        bytes32 xorSecrets;
        bytes32 output;
    }

    error Unauthorized();
    error InvalidConfiguration();
    error InvalidPhase();
    error InvalidFieldElement();
    error AlreadyCommitted();
    error AtCapacity();
    error InvalidProof();
    error InvalidReveal();
    error SeedExpired();

    address public immutable owner;
    IPoseidon3 public immutable poseidon;
    IKnowledgeVerifier public immutable verifier;
    uint256 public nextRoundId = 1;
    mapping(uint256 => Round) public rounds;
    mapping(uint256 => mapping(address => uint256)) public commitments;
    mapping(uint256 => mapping(address => bool)) public hasCommitted;
    mapping(uint256 => mapping(address => bool)) public hasRevealed;

    event RoundCreated(uint256 indexed roundId, uint256 commitEnd, uint256 maxParticipants, uint256 minReveals);
    event Registered(uint256 indexed roundId, address indexed participant, uint256 commitment);
    event SeedLocked(uint256 indexed roundId, bytes32 seed, uint256 revealEnd);
    event Revealed(uint256 indexed roundId, address indexed participant);
    event Finalized(uint256 indexed roundId, bytes32 output, uint256 revealCount);
    event Aborted(uint256 indexed roundId, uint256 revealCount);

    constructor(address verifier_, address poseidon_) {
        if (verifier_ == address(0) || poseidon_ == address(0)
            || verifier_.code.length == 0 || poseidon_.code.length == 0) {
            revert InvalidConfiguration();
        }
        owner = msg.sender;
        verifier = IKnowledgeVerifier(verifier_);
        poseidon = IPoseidon3(poseidon_);
    }

    /// @param commitEnd Last block at which registration is permitted.
    function createRound(
        uint64 commitEnd,
        uint16 maxParticipants,
        uint16 minReveals
    ) external returns (uint256 roundId) {
        if (msg.sender != owner) revert Unauthorized();
        if (commitEnd <= block.number || maxParticipants == 0
            || maxParticipants > MAX_PARTICIPANTS || minReveals == 0
            || minReveals > maxParticipants) revert InvalidConfiguration();

        roundId = nextRoundId++;
        rounds[roundId].commitEnd = commitEnd;
        rounds[roundId].maxParticipants = maxParticipants;
        rounds[roundId].minReveals = minReveals;
        rounds[roundId].status = Status.Committing;
        emit RoundCreated(roundId, commitEnd, maxParticipants, minReveals);
    }

    function register(
        uint256 roundId,
        uint256 commitment,
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c
    ) external {
        Round storage round = rounds[roundId];
        if (round.status != Status.Committing || block.number > round.commitEnd) {
            revert InvalidPhase();
        }
        if (hasCommitted[roundId][msg.sender]) revert AlreadyCommitted();
        if (round.commits >= round.maxParticipants) revert AtCapacity();
        if (commitment >= FIELD_MODULUS) revert InvalidFieldElement();

        uint256[3] memory publicSignals = [commitment, roundId, uint256(uint160(msg.sender))];
        if (!verifier.verifyProof(a, b, c, publicSignals)) revert InvalidProof();

        hasCommitted[roundId][msg.sender] = true;
        commitments[roundId][msg.sender] = commitment;
        round.commits++;
        emit Registered(roundId, msg.sender, commitment);
    }

    /// @notice Must be called after commitEnd and within the 256-block BLOCKHASH window.
    function lockSeed(uint256 roundId, uint64 revealBlocks) external {
        Round storage round = rounds[roundId];
        if (round.status != Status.Committing || block.number <= round.commitEnd) {
            revert InvalidPhase();
        }
        if (block.number - uint256(round.commitEnd) > 256) revert SeedExpired();
        if (revealBlocks == 0 || revealBlocks > MAX_REVEAL_BLOCKS
            || block.number + revealBlocks > type(uint64).max) revert InvalidConfiguration();
        bytes32 seed = blockhash(uint256(round.commitEnd));
        if (seed == bytes32(0)) revert SeedExpired();

        round.seedBlockHash = seed;
        round.revealEnd = uint64(block.number + revealBlocks);
        round.status = Status.Revealing;
        emit SeedLocked(roundId, seed, round.revealEnd);
    }

    function reveal(uint256 roundId, uint256 secret) external {
        Round storage round = rounds[roundId];
        if (round.status != Status.Revealing || block.number > round.revealEnd) {
            revert InvalidPhase();
        }
        if (!hasCommitted[roundId][msg.sender] || hasRevealed[roundId][msg.sender]
            || secret >= FIELD_MODULUS) revert InvalidReveal();

        uint256[3] memory preimage = [secret, roundId, uint256(uint160(msg.sender))];
        if (poseidon.poseidon(preimage) != commitments[roundId][msg.sender]) {
            revert InvalidReveal();
        }

        hasRevealed[roundId][msg.sender] = true;
        round.reveals++;
        round.xorSecrets ^= bytes32(secret);
        emit Revealed(roundId, msg.sender);
    }

    /// @notice Returns zero for aborted rounds. Consumers must check status.
    function finalize(uint256 roundId) external returns (bytes32 result) {
        Round storage round = rounds[roundId];
        if (round.status != Status.Revealing || block.number <= round.revealEnd) {
            revert InvalidPhase();
        }
        if (round.reveals < round.minReveals) {
            round.status = Status.Aborted;
            emit Aborted(roundId, round.reveals);
            return bytes32(0);
        }

        result = keccak256(abi.encode(
            "ZK_BEACON_V1", block.chainid, address(this), roundId,
            round.seedBlockHash, round.xorSecrets, round.reveals
        ));
        round.output = result;
        round.status = Status.Finalized;
        emit Finalized(roundId, result, round.reveals);
    }

    /// @notice Aborts a round if no caller captured its seed before BLOCKHASH expiry.
    function abortExpired(uint256 roundId) external {
        Round storage round = rounds[roundId];
        if (round.status != Status.Committing || block.number <= uint256(round.commitEnd) + 256) {
            revert InvalidPhase();
        }
        round.status = Status.Aborted;
        emit Aborted(roundId, 0);
    }
}
