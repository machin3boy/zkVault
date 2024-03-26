// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../interfaces/IzkVaultCore.sol";

contract MirroredERC20 is ERC20 {
    address public underlyingAsset;
    uint256 public requestId;
    string public username;
    address public owner;

    bool public transfersDisabled;
    uint256 public transferUnlockTimestamp;

    address public zkVaultCoreAddress;

    constructor(
        string memory name,
        string memory symbol,
        address _underlyingAsset,
        uint256 _requestId,
        string memory _username,
        address _owner,
        address _zkVaultCoreAddress
    ) ERC20(name, symbol) {
        underlyingAsset = _underlyingAsset;
        requestId = _requestId;
        username = _username;
        owner = _owner;
        zkVaultCoreAddress = _zkVaultCoreAddress;
    }

    function mint(address to, uint256 amount) public {
        require(msg.sender == owner, "Only the owner can mint tokens");
        _mint(to, amount);
    }

    function burnFrom(address account, uint256 amount) public {
        require(msg.sender == owner, "Only the owner can burn tokens");
        _burn(account, amount);
    }

    function disableTransfersPermanently() public {
        require(
            IzkVaultCore(zkVaultCoreAddress).usernameAddress(username) ==
                msg.sender,
            "Only the owner of the username can disable transfers"
        );
        require(!transfersDisabled, "Transfers already permanently disabled");
        transfersDisabled = true;
    }

    function setTransferUnlockTimestamp(uint256 unlockTime) public {
        require(
            IzkVaultCore(zkVaultCoreAddress).usernameAddress(username) ==
                msg.sender,
            "Only the owner of the username can set the unlock timestamp"
        );
        require(
            unlockTime > block.timestamp,
            "Unlock time must be in the future"
        );
        require(
            unlockTime > transferUnlockTimestamp,
            "New unlock time must be higher"
        );
        transferUnlockTimestamp = unlockTime;
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        require(
            msg.sender == owner ||
                recipient == owner ||
                (!transfersDisabled &&
                    block.timestamp >= transferUnlockTimestamp),
            "Transfers are disabled"
        );
        return super.transfer(recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        require(
            sender == owner ||
                recipient == owner ||
                (!transfersDisabled &&
                    block.timestamp >= transferUnlockTimestamp),
            "Transfers are disabled"
        );
        return super.transferFrom(sender, recipient, amount);
    }
}
