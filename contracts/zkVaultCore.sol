// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
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

    function releaseOwnership() public {
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

    mapping(string => mapping(uint256 => address)) public mirroredERC20Tokens;
    mapping(string => mapping(uint256 => address)) public mirroredERC721Tokens;
    mapping(string => uint256) public mirroredTokenRequestCount;

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

        // Mint mirrored ERC20 tokens
        string memory username = usernames[msg.sender];
        uint256 requestId = mirroredTokenRequestCount[username];
        string memory name = string(
            abi.encodePacked("Mirrored ", ERC20(_token).name())
        );
        string memory symbol = string(
            abi.encodePacked("m", ERC20(_token).symbol())
        );
        address mirroredToken = address(
            new MirroredERC20(name, symbol, _token, requestId, username)
        );
        mirroredERC20Tokens[username][requestId] = mirroredToken;
        MirroredERC20(mirroredToken).mint(msg.sender, _amount);
        mirroredTokenRequestCount[username]++;
    }

    function unlockERC20(
        address _token,
        uint256 _amount,
        uint256 _requestId
    ) external {
        require(_amount > 0, "Amount must be greater than zero");
        require(
            IERC20(_token).balanceOf(address(this)) >= _amount,
            "Insufficient balance in the contract"
        );

        string memory username = usernames[msg.sender];
        address mirroredToken = mirroredERC20Tokens[username][_requestId];
        require(mirroredToken != address(0), "Mirrored token does not exist");
        require(
            MirroredERC20(mirroredToken).balanceOf(msg.sender) >= _amount,
            "Insufficient mirrored token balance"
        );

        // Burn mirrored ERC20 tokens
        MirroredERC20(mirroredToken).burnFrom(msg.sender, _amount);

        IERC20(_token).transfer(msg.sender, _amount);
    }

    function lockERC721(address _token, uint256 _tokenId) external {
        require(
            IERC721(_token).ownerOf(_tokenId) == msg.sender,
            "Caller is not the owner of the token"
        );

        IERC721(_token).transferFrom(msg.sender, address(this), _tokenId);

        // Mint mirrored ERC721 token
        string memory username = usernames[msg.sender];
        uint256 requestId = mirroredTokenRequestCount[username];
        string memory name = string(
            abi.encodePacked("Mirrored ", ERC721(_token).name())
        );
        string memory symbol = string(
            abi.encodePacked("m", ERC721(_token).symbol())
        );
        address mirroredToken = address(
            new MirroredERC721(name, symbol, _token, requestId, username)
        );
        mirroredERC721Tokens[username][requestId] = mirroredToken;
        MirroredERC721(mirroredToken).mint(msg.sender, _tokenId);
        mirroredTokenRequestCount[username]++;
    }

    function unlockERC721(
        address _token,
        uint256 _tokenId,
        uint256 _requestId
    ) external {
        require(
            IERC721(_token).ownerOf(_tokenId) == address(this),
            "Contract is not the owner of the token"
        );

        string memory username = usernames[msg.sender];
        address mirroredToken = mirroredERC721Tokens[username][_requestId];
        require(mirroredToken != address(0), "Mirrored token does not exist");
        require(
            MirroredERC721(mirroredToken).ownerOf(_tokenId) == msg.sender,
            "Caller is not the owner of the mirrored token"
        );

        // Burn mirrored ERC721 token
        MirroredERC721(mirroredToken).burn(_tokenId);

        IERC721(_token).transferFrom(address(this), msg.sender, _tokenId);
    }
}

contract MirroredERC20 is ERC20 {
    address public underlyingAsset;
    uint256 public requestId;
    string public username;

    constructor(
        string memory name,
        string memory symbol,
        address _underlyingAsset,
        uint256 _requestId,
        string memory _username
    ) ERC20(name, symbol) {
        underlyingAsset = _underlyingAsset;
        requestId = _requestId;
        username = _username;
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burnFrom(address account, uint256 amount) public {
        _burn(account, amount);
    }
}

contract MirroredERC721 is ERC721 {
    address public underlyingAsset;
    uint256 public requestId;
    string public username;

    constructor(
        string memory name,
        string memory symbol,
        address _underlyingAsset,
        uint256 _requestId,
        string memory _username
    ) ERC721(name, symbol) {
        underlyingAsset = _underlyingAsset;
        requestId = _requestId;
        username = _username;
    }

    function mint(address to, uint256 tokenId) public {
        _safeMint(to, tokenId);
    }

    function burn(uint256 tokenId) public {
        _burn(tokenId);
    }
}
