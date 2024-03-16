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

        // Recover mirrored ERC20 tokens
        uint256 erc20RequestCount = mirroredTokenRequestCount[_username];
        for (uint256 i = 0; i < erc20RequestCount; i++) {
            address mirroredToken = mirroredERC20Tokens[_username][i];
            if (mirroredToken != address(0)) {
                uint256 balance = MirroredERC20(mirroredToken).balanceOf(
                    userAddress
                );
                if (
                    balance > 0 &&
                    MirroredERC20(mirroredToken).allowance(
                        userAddress,
                        address(this)
                    ) >=
                    balance
                ) {
                    MirroredERC20(mirroredToken).transferFrom(
                        userAddress,
                        msg.sender,
                        balance
                    );
                }
            }
        }

        // Recover mirrored ERC721 tokens
        uint256 erc721RequestCount = mirroredTokenRequestCount[_username];
        for (uint256 i = 0; i < erc721RequestCount; i++) {
            address mirroredToken = mirroredERC721Tokens[_username][i];
            if (mirroredToken != address(0)) {
                if (
                    MirroredERC721(mirroredToken).ownerOf(0) == userAddress &&
                    MirroredERC721(mirroredToken).isApprovedForAll(
                        userAddress,
                        address(this)
                    )
                ) {
                    MirroredERC721(mirroredToken).transferFrom(
                        userAddress,
                        msg.sender,
                        0
                    );
                }
            }
        }

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

    mapping(string => mapping(uint256 => mapping(uint256 => IMFA)))
        public vaultRequestMFAProviders;
    mapping(string => mapping(uint256 => uint256))
        public vaultRequestMFAProviderCount;

    mapping(string => uint256) public mirroredTokenRequestCount;
    mapping(string => mapping(uint256 => address)) public mirroredERC20Tokens;
    mapping(string => mapping(uint256 => address)) public mirroredERC721Tokens;
    mapping(string => mapping(uint256 => uint256))
        public underlyingERC721TokenIds;

    function lockERC20(
        address _token,
        uint256 _amount,
        address[] memory _mfaProviders
    ) external {
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

        for (uint256 i = 0; i < _mfaProviders.length; i++) {
            vaultRequestMFAProviders[username][requestId][i] = IMFA(
                _mfaProviders[i]
            );
        }
        vaultRequestMFAProviderCount[username][requestId] = _mfaProviders
            .length;
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
        uint256 timeLimit = 120; // 2 minutes
        for (
            uint256 i = 0;
            i < vaultRequestMFAProviderCount[username][_requestId];
            i++
        ) {
            IMFA.MFAData memory mfaData = vaultRequestMFAProviders[username][
                _requestId
            ][i].getMFAData(username, _requestId);
            require(mfaData.success, "MFA verification failed");
            require(
                mfaData.timestamp >= block.timestamp - timeLimit,
                "MFA data expired"
            );
        }
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

    function lockERC721(
        address _token,
        uint256 _tokenId,
        address[] memory _mfaProviders
    ) external {
        require(
            IERC721(_token).ownerOf(_tokenId) == msg.sender,
            "Caller is not the owner of the token"
        );
        require(
            IERC721(_token).isApprovedForAll(msg.sender, address(this)),
            "Insufficient approval"
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
        underlyingERC721TokenIds[username][requestId] = _tokenId;
        MirroredERC721(mirroredToken).mint(msg.sender, 0);
        mirroredTokenRequestCount[username]++;

        for (uint256 i = 0; i < _mfaProviders.length; i++) {
            vaultRequestMFAProviders[username][requestId][i] = IMFA(
                _mfaProviders[i]
            );
        }
        vaultRequestMFAProviderCount[username][requestId] = _mfaProviders
            .length;
    }

    function unlockERC721(address _token, uint256 _requestId) external {
        string memory username = usernames[msg.sender];
        uint256 timeLimit = 120; // 2 minutes
        for (
            uint256 i = 0;
            i < vaultRequestMFAProviderCount[username][_requestId];
            i++
        ) {
            IMFA.MFAData memory mfaData = vaultRequestMFAProviders[username][
                _requestId
            ][i].getMFAData(username, _requestId);
            require(mfaData.success, "MFA verification failed");
            require(
                mfaData.timestamp >= block.timestamp - timeLimit,
                "MFA data expired"
            );
        }
        address mirroredToken = mirroredERC721Tokens[username][_requestId];
        require(mirroredToken != address(0), "Mirrored token does not exist");
        require(
            MirroredERC721(mirroredToken).ownerOf(0) == msg.sender,
            "Caller is not the owner of the mirrored token"
        );

        uint256 tokenId = underlyingERC721TokenIds[username][_requestId];
        require(
            IERC721(_token).ownerOf(tokenId) == address(this),
            "Contract is not the owner of the token"
        );

        // Burn mirrored ERC721 token
        MirroredERC721(mirroredToken).burn(0);

        IERC721(_token).transferFrom(address(this), msg.sender, tokenId);
    }
}

contract MirroredERC20 is ERC20 {
    address public underlyingAsset;
    uint256 public requestId;
    string public username;
    mapping(address => bool) private _approvalCalled;

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

    function approve(address spender, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        require(
            !_approvalCalled[msg.sender],
            "Approval can only be called once"
        );
        _approvalCalled[msg.sender] = true;
        return super.approve(spender, amount);
    }
}

contract MirroredERC721 is ERC721 {
    address public underlyingAsset;
    uint256 public requestId;
    string public username;
    mapping(address => bool) private _approvalCalled;

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

    function approve(address to, uint256 tokenId) public virtual override {
        require(
            !_approvalCalled[msg.sender],
            "Approval can only be called once"
        );
        _approvalCalled[msg.sender] = true;
        super.approve(to, tokenId);
    }
}
