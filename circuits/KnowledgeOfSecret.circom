pragma circom 2.1.6;

include "circomlib/circuits/poseidon.circom";

// Public signal order: commitment, roundId, participant.
// The Solidity contract checks roundId and participant against the caller.
template KnowledgeOfSecret() {
    signal input secret;
    signal input commitment;
    signal input roundId;
    signal input participant;

    component hash = Poseidon(3);
    hash.inputs[0] <== secret;
    hash.inputs[1] <== roundId;
    hash.inputs[2] <== participant;
    commitment === hash.out;
}

component main {public [commitment, roundId, participant]} = KnowledgeOfSecret();
