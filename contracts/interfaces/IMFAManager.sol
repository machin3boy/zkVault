// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IMFA.sol";
import "./IGroth16VerifierP2.sol";

interface IMFAManager {
    function setzkVaultMFAAddress(address _zkVaultMFAAddress) external;

    function getZkVaultMFAAddress() external view returns (address);

    function registerMFAProvider(address provider) external;

    function deregisterMFAProvider(address provider) external;

    function setMFAProviders(
        string memory username,
        uint256 requestId,
        address[] memory _mfaProviders
    ) external;

    function verifyMFA(
        string memory username,
        uint256 requestId,
        uint256 timestamp,
        ProofParameters memory _zkpParams,
        MFAProviderData[] memory _mfaProviderData
    ) external returns (bool);

    function getVaultRequestMFAProviderCount(
        string memory username,
        uint256 requestId
    ) external view returns (uint256);

    function getVaultRequestMFAProviders(
        string memory username,
        uint256 requestId,
        uint256 index
    ) external view returns (address);
}
