// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract zkVaultCore is ERC20 {
    mapping(address => string) public usernames;
    mapping(address => uint256) public passwordHashes;

    constructor(uint256 initialSupply) ERC20("VaultToken", "VAULT") {
        _mint(msg.sender, initialSupply);
    }

    function setUsername(string memory _username, uint256 _passwordHash) external {
        require(bytes(usernames[msg.sender]).length == 0, "Username already set");
        usernames[msg.sender] = _username;
        passwordHashes[msg.sender] = _passwordHash;
    }
}

