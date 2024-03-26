// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IMFAManager.sol";
import "../interfaces/IzkVaultCore.sol";

contract MFAManager is IMFAManager {
    mapping(string => mapping(uint256 => mapping(uint256 => IMFA)))
        public vaultRequestMFAProviders;
    mapping(string => mapping(uint256 => uint256))
        public vaultRequestMFAProviderCount;

    address public zkVaultMFAAddress;
    address public zkVaultCoreAddress;
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function setzkVaultMFAAddress(address _zkVaultMFAAddress) external {
        require(
            msg.sender == owner,
            "Only owner can set the zkVaultMFA address"
        );
        zkVaultMFAAddress = _zkVaultMFAAddress;
    }

    function setzkVaultCoreAddress(address _zkVaultCoreAddress) external {
        require(
            msg.sender == owner,
            "Only owner can set the zkVaultCore address"
        );
        zkVaultCoreAddress = _zkVaultCoreAddress;
    }

    function getZkVaultMFAAddress() external view returns (address) {
        return zkVaultMFAAddress;
    }

    function setMFAProviders(
        string memory username,
        uint256 requestId,
        address[] memory _mfaProviders
    ) external {
        require(
            (msg.sender == zkVaultCoreAddress &&
                zkVaultCoreAddress != address(0)) ||
                IzkVaultCore(zkVaultCoreAddress).usernameAddress(username) ==
                msg.sender ||
                msg.sender == address(this),
            "Only the zkVaultCore contract, the owner of the username, or the MFA manager can set MFA providers"
        );

        for (uint256 i = 0; i < _mfaProviders.length; ++i) {
            vaultRequestMFAProviders[username][requestId][i] = IMFA(
                _mfaProviders[i]
            );
        }
        vaultRequestMFAProviderCount[username][requestId] = _mfaProviders
            .length;
    }

    function verifyMFA(
        string memory username,
        uint256 requestId,
        uint256 timestamp,
        ProofParameters memory _zkpParams,
        MFAProviderData[] memory _mfaProviderData
    ) external returns (bool) {
        require(
            (msg.sender == zkVaultCoreAddress &&
                zkVaultCoreAddress != address(0)) ||
                IzkVaultCore(zkVaultCoreAddress).usernameAddress(username) ==
                msg.sender,
            "Only the zkVaultCore contract or the owner of the username can verify MFA"
        );

        uint256 timeLimit = 600; // 10 minutes

        for (uint256 i = 0; i < _mfaProviderData.length; ++i) {
            if (_mfaProviderData[i].providerAddress == zkVaultMFAAddress) {
                IzkVaultMFA(zkVaultMFAAddress).setMFAData(
                    username,
                    requestId,
                    timestamp,
                    _zkpParams
                );
            } else {
                IExternalSignerMFA(_mfaProviderData[i].providerAddress)
                    .setValue(
                        username,
                        requestId,
                        timestamp,
                        _mfaProviderData[i].message,
                        _mfaProviderData[i].v,
                        _mfaProviderData[i].r,
                        _mfaProviderData[i].s
                    );
            }
        }

        for (
            uint256 i = 0;
            i < vaultRequestMFAProviderCount[username][requestId];
            ++i
        ) {
            IMFA.MFAData memory mfaData = vaultRequestMFAProviders[username][
                requestId
            ][i].getMFAData(username, requestId);
            require(mfaData.success, "MFA verification failed");
            require(
                mfaData.timestamp >= block.timestamp - timeLimit,
                "MFA data expired"
            );
        }

        return true;
    }

    function getVaultRequestMFAProviderCount(
        string memory username,
        uint256 requestId
    ) external view returns (uint256) {
        return vaultRequestMFAProviderCount[username][requestId];
    }

    function getVaultRequestMFAProviders(
        string memory username,
        uint256 requestId,
        uint256 index
    ) external view returns (address) {
        return address(vaultRequestMFAProviders[username][requestId][index]);
    }
}
