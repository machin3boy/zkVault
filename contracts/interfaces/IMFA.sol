// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IGroth16VerifierP2.sol";
import "./interfaces/IMFA.sol";


/*         88      8b           d8                         88              
           88      `8b         d8'                         88    ,d        
           88       `8b       d8'                          88    88        
888888888  88   ,d8  `8b     d8'  ,adPPYYba,  88       88  88  MM88MMM     
     a8P"  88 ,a8"    `8b   d8'   ""     `Y8  88       88  88    88        
  ,d8P'    8888[       `8b d8'    ,adPPPPP88  88       88  88    88        
,d8"       88`"Yba,     `888'     88,    ,88  "8a,   ,a88  88    88,       
888888888  88   `Y8a     `8'      `"8bbdP"Y8   `"YbbdP'Y8  88    "Y8*/                                                                         

contract zkVaultCore is ERC20 {
    mapping(address => string) public usernames;
    mapping(string => address) public addressByUsername;
    mapping(address => uint256) public passwordHashes;

    mapping(address => IMFA) public _MFAProviders;
    mapping(address => address) public _MFAProviderOwners;

    //ZKP Solidity verifier
    IGroth16VerifierP2 public passwordVerifier;

    uint256 private constant tokenSupply = 10000000000 * 10**18;

    constructor(address _passwordVerifier) ERC20("zkVault", "VAULT") {
        _mint((address(this)), tokenSupply);
        passwordVerifier = IGroth16VerifierP2(_passwordVerifier);
    }

    function vaultTokensFaucet() public {
        _transfer(address(this), msg.sender, 10000 * 10**18);
    }

    function setUsername(string memory _username, uint256 _passwordHash)
        external
    {
        require(
            bytes(usernames[msg.sender]).length == 0,
            "Username already set"
        );
        usernames[msg.sender] = _username;
        addressByUsername[_username] = msg.sender;
        passwordHashes[msg.sender] = _passwordHash;
    }

    function resetUsername(
        string memory _username,
        uint256 passwordHash,
        uint256 timestamp,
        ProofParameters calldata params
    ) external {
        address userAddress = addressByUsername[_username];
        require(userAddress != address(0), "Username does not exist");

        // Verify password
        verifyPassword(passwordHashes[userAddress], timestamp, params);

        // Clear old mappings
        delete addressByUsername[_username];
        delete usernames[userAddress];

        // Reset mappings
        usernames[msg.sender] = _username;
        addressByUsername[_username] = msg.sender;
        passwordHashes[msg.sender] = passwordHash;
    }

    function verifyPassword(
        uint256 passwordHash,
        uint256 timestamp,
        ProofParameters calldata params
    ) public view {
        uint256 timeLimit = 300;
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
            pubSignals[0] == passwordHash &&
                pubSignals[1] == timestamp &&
                passwordVerifier.verifyProof(pA, pB, pC, pubSignals),
            "ZKP verification failed."
        );
    }

    function registerMFAProvider(address provider) public {
        require(
            _MFAProviders[provider] == IMFA(address(0)),
            "Provider already exists"
        );
        _MFAProviders[provider] = IMFA(provider);
        _MFAProviderOwners[provider] = msg.sender;
    }

    function deregisterMFAProvider(address provider) public {
        require(
            msg.sender == _MFAProviderOwners[provider],
            "Not the owner of this MFA provider"
        );
        delete _MFAProviders[provider];
        delete _MFAProviderOwners[provider];
    }

}
