// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "../interfaces/IzkVaultCore.sol";

contract MirroredERC721 is ERC721 {
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
    ) ERC721(name, symbol) {
        underlyingAsset = _underlyingAsset;
        requestId = _requestId;
        username = _username;
        owner = _owner;
        zkVaultCoreAddress = _zkVaultCoreAddress;
    }

    function mint(address to, uint256 tokenId) public {
        require(msg.sender == owner, "Only owner can mint tokens");
        _safeMint(to, tokenId);
    }

    function burn(uint256 tokenId) public {
        require(msg.sender == owner, "Only owner can burn tokens");
        _burn(tokenId);
    }

    function ownerOfToken(uint256 tokenId) public view returns (address) {
        return _ownerOf(tokenId);
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

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        address usernameOwner = IzkVaultCore(zkVaultCoreAddress)
            .usernameAddress(username);
        require(
            from == owner ||
                to == owner ||
                to == usernameOwner ||
                (!transfersDisabled &&
                    block.timestamp >= transferUnlockTimestamp),
            "Outgoing transfers are disabled"
        );
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override {
        address usernameOwner = IzkVaultCore(zkVaultCoreAddress)
            .usernameAddress(username);
        require(
            from == owner ||
                to == owner ||
                to == usernameOwner ||
                (!transfersDisabled &&
                    block.timestamp >= transferUnlockTimestamp),
            "Outgoing transfers are disabled"
        );
        super.safeTransferFrom(from, to, tokenId, data);
    }
}
