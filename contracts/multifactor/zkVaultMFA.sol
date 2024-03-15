pragma solidity ^0.8.7;

import "../interfaces/IGroth16VerifierP2.sol";

contract zkVaultMFA {
    IGroth16VerifierP2 private passwordVerifier;

    struct MFAData {
        bool success;
        uint256 timestamp;
    }

    mapping(uint256 => uint256) public MFARequestPasswordHashes;
    mapping(uint256 => MFAData) public MFARequestData;

    constructor(address _passwordVerifier) {
        passwordVerifier = IGroth16VerifierP2(_passwordVerifier);
    }

    function setRequestPasswordHash(
        uint256 _requestID,
        uint256 _requestPasswordHash
    ) public {
        MFARequestPasswordHashes[_requestID] = _requestPasswordHash;
    }

    function setMFAData(
        uint256 _requestID,
        uint256 timestamp,
        ProofParameters calldata params
    ) external {
        uint256 timeLimit = 120;
        require(timestamp <= block.timestamp);
        require(timestamp >= block.timestamp - timeLimit);

        uint256[2] memory pA = [params.pA0, params.pA1];
        uint256[2][2] memory pB = [
            [params.pB00, params.pB01],
            [params.pB10, params.pB11]
        ];
        uint256[2] memory pC = [params.pC0, params.pC1];
        uint256[2] memory pubSignals = [params.pubSignals0, params.pubSignals1];

        require(
            pubSignals[0] == MFARequestPasswordHashes[_requestID] &&
                pubSignals[1] == timestamp &&
                passwordVerifier.verifyProof(pA, pB, pC, pubSignals),
            "ZKP verification failed."
        );

        MFARequestData[_requestID].success = true;
        MFARequestData[_requestID].timestamp = block.timestamp;
    }

    function getMFAData(uint256 _requestID)
        external
        view
        returns (MFAData memory)
    {
        return MFARequestData[_requestID];
    }
}
