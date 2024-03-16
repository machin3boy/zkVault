// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
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
    mapping(string => address) public usernameAddress;
    mapping(address => uint256) public passwordHashes;

    mapping(address => IMFA) public MFAProviders;
    mapping(address => address) public MFAProviderOwners;

    mapping(uint256 => mapping(uint256 => IMFA)) vaultRequestMFAProviders;
    mapping(string => uint256) vaultRequestIDCount;

    //ZKP Solidity verifier
    IGroth16VerifierP2 public passwordVerifier;

    address public owner;

    constructor() ERC20("zkVault", "VAULT") {
        _mint((address(this)), 10000000000 * 10**18);
        owner = msg.sender;
    }

    function releaseOnwership() public {
        require(msg.sender == owner, "Not owner");
        owner = address(0);
    }

    function setPasswordVerifier(address _passwordVerifier) public {
        require(msg.sender == owner, "Not owner");
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
        usernameAddress[_username] = msg.sender;
        vaultRequestIDCount[_username] = 0;
        passwordHashes[msg.sender] = _passwordHash;
    }

    function resetUsernameAddress(
        string memory _username,
        uint256 passwordHash,
        uint256 timestamp,
        ProofParameters calldata params
    ) external {
        address userAddress = usernameAddress[_username];
        require(userAddress != address(0), "Username does not exist");

        // Verify password
        verifyPassword(passwordHashes[userAddress], timestamp, params);

        // Clear old mappings
        delete usernameAddress[_username];
        delete usernames[userAddress];

        // Reset mappings
        usernames[msg.sender] = _username;
        usernameAddress[_username] = msg.sender;
        passwordHashes[msg.sender] = passwordHash;
    }

    function verifyPassword(
        uint256 passwordHash,
        uint256 timestamp,
        ProofParameters calldata params
    ) public view {
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
            pubSignals[0] == passwordHash &&
                pubSignals[1] == timestamp &&
                passwordVerifier.verifyProof(pA, pB, pC, pubSignals),
            "ZKP verification failed."
        );
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
            "Not the owner of this MFA provider"
        );
        delete MFAProviders[provider];
        delete MFAProviderOwners[provider];
    }

    function lockERC20(address _token, uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than zero");
        require(
            IERC20(_token).balanceOf(msg.sender) >= _amount,
            "Insufficient balance"
        );
        require(
            IERC20(_token).allowance(msg.sender, address(this)) >= _amount,
            "Insufficient allowance"
        );

        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
    }

    function unlockERC20(address _token, uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than zero");
        require(
            IERC20(_token).balanceOf(address(this)) >= _amount,
            "Insufficient balance in the contract"
        );

        IERC20(_token).transfer(msg.sender, _amount);
    }

    function lockERC721(address _token, uint256 _tokenId) external {
        require(
            IERC721(_token).ownerOf(_tokenId) == msg.sender,
            "Caller is not the owner of the token"
        );
        IERC721(_token).transferFrom(msg.sender, address(this), _tokenId);
    }

    function unlockERC721(address _token, uint256 _tokenId) external {
        require(
            IERC721(_token).ownerOf(_tokenId) == address(this),
            "Contract is not the owner of the token"
        );
        IERC721(_token).transferFrom(address(this), msg.sender, _tokenId);
    }
}
