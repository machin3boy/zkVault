// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/IMFAManager.sol";

contract MFAManager is IMFAManager {
    mapping(address => IMFA) public MFAProviders;
    mapping(address => address) public MFAProviderOwners;

    mapping(string => mapping(uint256 => mapping(uint256 => IMFA)))
        public vaultRequestMFAProviders;
    mapping(string => mapping(uint256 => uint256))
        public vaultRequestMFAProviderCount;

    address public zkVaultMFAAddress;
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

    function getZkVaultMFAAddress() external view returns (address) {
        return zkVaultMFAAddress;
    }

    function registerMFAProvider(address provider) public {
        require(
            MFAProviders[provider] == IMFA(address(0)),
            "Provider already exists"
        );
        MFAProviders[provider] = IMFA(provider);
        MFAProviderOwners[provider] = msg.sender;
    }

    function deregisterMFAProvider(address provider) public {
        require(
            msg.sender == MFAProviderOwners[provider],
            "Not owner of this MFA provider"
        );
        delete MFAProviders[provider];
        delete MFAProviderOwners[provider];
    }

    function setMFAProviders(
        string memory username,
        uint256 requestId,
        address[] memory _mfaProviders
    ) external {
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
        uint256 timeLimit = 600; // 10 minutes

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
