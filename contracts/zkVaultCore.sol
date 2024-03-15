// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
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
    mapping(string => address) public addressByUsername;
    mapping(address => uint256) public passwordHashes;

    mapping(address => IMFA) public MFAProviders;
    mapping(address => address) public MFAProviderOwners;

    mapping(uint256 => mapping(uint256 => IMFA)) vaultRequestIds;
    mapping(uint256 => uint256) vaultRequestIdCounts;

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

    struct MirroredERC20Asset {
        address underlyingAssetAddress;
        address mirroredTokenAddress;
        ERC20 mirroredToken;
    }

    struct MirroredERC721Asset {
        address underlyingAssetAddress;
        address mirroredTokenAddress;
        ERC721 mirroredToken;
    }

    mapping(string => mapping(uint256 => MirroredERC20Asset))
        public mirroredERC20Assets;
    mapping(string => mapping(uint256 => MirroredERC721Asset))
        public mirroredERC721Assets;

    function lockToken(
        address _nativeAsset,
        uint256 _amount,
        string memory _symbol,
        bool _isNFT,
        uint256 _tokenId,
        uint256 _requestId,
        address[] memory _MFAProviders
    ) public {
        require(
            mirroredERC20Assets[usernames[msg.sender]][_requestId]
                .mirroredTokenAddress ==
                address(0) &&
                mirroredERC721Assets[usernames[msg.sender]][_requestId]
                    .mirroredTokenAddress ==
                address(0),
            "Mirrored asset already exists"
        );

        if (!_isNFT) {
            // Create a new ERC20 token for the mirrored asset
            ERC20 mirroredToken = new zkVaultMirroredERC20(
                string(abi.encodePacked("Mirrored ", _symbol)), // Symbol for the mirrored asset
                string(abi.encodePacked("m", _symbol)), // Name for the mirrored asset
                _amount,
                _nativeAsset
            );

            ERC20(_nativeAsset).transferFrom(
                msg.sender,
                address(this),
                _amount
            );

            // Store information about the mirrored asset
            mirroredERC20Assets[usernames[msg.sender]][
                _requestId
            ] = MirroredERC20Asset(
                _nativeAsset,
                address(mirroredToken),
                mirroredToken
            );
        } else {
            // Create a new ERC721 token for the mirrored asset
            ERC721 mirroredToken = new zkVaultMirroredERC721(
                string(abi.encodePacked("Mirrored ", _symbol)), // Symbol for the mirrored asset
                string(abi.encodePacked("m", _symbol)), // Name for the mirrored asset
                _tokenId,
                _nativeAsset
            );

            ERC721(_nativeAsset).transferFrom(
                msg.sender,
                address(this),
                _tokenId
            );

            // Store information about the mirrored asset
            mirroredERC721Assets[usernames[msg.sender]][
                _requestId
            ] = MirroredERC721Asset(
                _nativeAsset,
                address(mirroredToken),
                mirroredToken
            );
        }
    }

    function unlockToken(
        uint256 _amount,
        uint256 _tokenId,
        uint256 _requestId
    ) public {
        // Retrieve the mirrored ERC20 asset for the user and requestId
        MirroredERC20Asset storage mirroredERC20Asset = mirroredERC20Assets[
            usernames[msg.sender]
        ][_requestId];

        // Retrieve the mirrored ERC721 asset for the user and requestId
        MirroredERC721Asset storage mirroredERC721Asset = mirroredERC721Assets[
            usernames[msg.sender]
        ][_requestId];

        require(
            mirroredERC20Asset.mirroredTokenAddress != address(0) ||
                mirroredERC721Asset.mirroredTokenAddress != address(0),
            "Mirrored asset does not exist"
        );

        if (mirroredERC20Asset.mirroredTokenAddress != address(0)) {
            // ERC20 mirrored asset
            require(
                mirroredERC20Asset.mirroredToken.balanceOf(msg.sender) >=
                    _amount,
                "Insufficient mirrored balance"
            );

            // Transfer mirrored ERC20 tokens from the sender to the contract
            mirroredERC20Asset.mirroredToken.transferFrom(
                msg.sender,
                address(this),
                _amount
            );

            // Transfer ERC20 tokens back to the sender
            ERC20(mirroredERC20Asset.underlyingAssetAddress).transfer(
                msg.sender,
                _amount
            );
        } else {
            // ERC721 mirrored asset
            require(
                mirroredERC721Asset.mirroredToken.ownerOf(_tokenId) ==
                    msg.sender,
                "Not token owner"
            );

            // Transfer ERC721 token back to the sender
            mirroredERC721Asset.mirroredToken.transferFrom(
                msg.sender,
                address(this),
                _tokenId
            );

            // Transfer ERC721 token back to the sender
            ERC721(mirroredERC721Asset.underlyingAssetAddress).transferFrom(
                address(this),
                msg.sender,
                _tokenId
            );
        }
    }
}

contract zkVaultMirroredERC20 is ERC20 {
    address public underlyingAssetAddress;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _supply,
        address _underlyingAssetAddress
    ) ERC20(_name, _symbol) {
        _mint(msg.sender, _supply);
        underlyingAssetAddress = _underlyingAssetAddress;
    }
}

contract zkVaultMirroredERC721 is ERC721 {
    address public underlyingAssetAddress;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _tokenId,
        address _underlyingAssetAddress
    ) ERC721(_name, _symbol) {
        _mint(msg.sender, _tokenId);
        underlyingAssetAddress = _underlyingAssetAddress;
    }
}
