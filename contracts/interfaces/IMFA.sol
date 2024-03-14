// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IMFA {
    struct MFAData {
        bool success;
        uint256 timestamp;
    }

    function setMFAData(uint256 requestId, bool success) external;

    function setMFADataWithSignature(
        uint256 requestId,
        bool success,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function getMFAData(uint256 requestId)
        external
        view
        returns (MFAData memory);
}
