// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IMFAManager.sol";

/*         88      8b           d8                         88              
           88      `8b         d8'                         88    ,d        
           88       `8b       d8'                          88    88        
888888888  88   ,d8  `8b     d8'  ,adPPYYba,  88       88  88  MM88MMM     
     a8P"  88 ,a8"    `8b   d8'   ""     `Y8  88       88  88    88        
  ,d8P'    8888{       `8b d8'    ,adPPPPP88  88       88  88    88        
,d8"       88`"Yba,     `888'     88,    ,88  "8a,   ,a88  88    88,       
888888888  88   `Y8a     `8'      `"8bbdP"Y8   `"YbbdP'Y8  88    "Y8*/

contract zkVaultCore is ERC20 {
    mapping(address => string) public usernames;
    mapping(string => address) public usernameAddress;
    mapping(address => uint256) public passwordHashes;

    //ZKP Solidity verifier
    IGroth16VerifierP2 public passwordVerifier;

    address public owner;
    address public deployer;

    address public mfaManagerAddress;
    IMFAManager public mfaManager;

    constructor(address _mfaManagerAddress, address _passwordVerifier)
        ERC20("zkVault", "VAULT")
    {
        _mint((address(this)), 10000000000 * 10**18);
        owner = msg.sender;
        deployer = msg.sender;
        mfaManager = IMFAManager(_mfaManagerAddress);
        mfaManagerAddress = _mfaManagerAddress;
        passwordVerifier = IGroth16VerifierP2(_passwordVerifier);
    }

    function releaseOwnership() public {
        require(msg.sender == owner, "Not owner");
        owner = address(0);
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
        for (uint256 i = 0; i < erc20RequestCount; ++i) {
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
                    // Transfer tokens from user address to contract
                    MirroredERC20(mirroredToken).transferFrom(
                        userAddress,
                        address(this),
                        balance
                    );
                    // Transfer tokens from contract to new user address
                    MirroredERC20(mirroredToken).transfer(msg.sender, balance);
                }
            }
        }

        // Recover mirrored ERC721 tokens
        uint256 erc721RequestCount = mirroredTokenRequestCount[_username];
        for (uint256 i = 0; i < erc721RequestCount; ++i) {
            address mirroredToken = mirroredERC721Tokens[_username][i];
            if (mirroredToken != address(0)) {
                if (
                    MirroredERC721(mirroredToken).exists(0) &&
                    MirroredERC721(mirroredToken).ownerOf(0) == userAddress &&
                    MirroredERC721(mirroredToken).isApprovedForAll(
                        userAddress,
                        address(this)
                    )
                ) {
                    // Transfer token from user address to contract
                    MirroredERC721(mirroredToken).transferFrom(
                        userAddress,
                        address(this),
                        0
                    );
                    // Transfer token from contract to new user address
                    MirroredERC721(mirroredToken).transferFrom(
                        address(this),
                        msg.sender,
                        0
                    );
                }
            }
        }

        // Reset mappings
        delete usernames[userAddress];
        usernames[msg.sender] = _username;
        usernameAddress[_username] = msg.sender;
        passwordHashes[msg.sender] = passwordHash;
    }

    function verifyPassword(
        uint256 passwordHash,
        uint256 timestamp,
        ProofParameters calldata params
    ) public view {
        uint256 timeLimit = 600;
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

    mapping(string => uint256) public mirroredTokenRequestCount;
    mapping(string => mapping(uint256 => address)) public mirroredERC20Tokens;
    mapping(string => mapping(uint256 => address)) public mirroredERC721Tokens;
    mapping(string => mapping(uint256 => uint256))
        public underlyingERC721TokenIds;

    event MirroredERC20Minted(
        string username,
        string tokenSymbol,
        uint256 amount
    );

    event MirroredERC721Minted(
        string username,
        string tokenName,
        string tokenSymbol
    );

    function lockAsset(
        address _token,
        uint256 _amount,
        uint256 _tokenId,
        bool _isERC20,
        address[] memory _mfaProviders
    ) public {
        require(
            _mfaProviders.length > 0,
            "At least one MFA provider is required"
        );

        _transfer(msg.sender, address(this), _mfaProviders.length * 10**18);

        if (_isERC20) {
            require(_amount > 0, "Invalid amount");
            require(
                IERC20(_token).balanceOf(msg.sender) >= _amount,
                "Insufficient balance"
            );
            require(
                IERC20(_token).allowance(msg.sender, address(this)) >= _amount,
                "Insufficient allowance"
            );
            IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        } else {
            require(
                IERC721(_token).ownerOf(_tokenId) == msg.sender,
                "Caller is not owner of token"
            );
            IERC721(_token).transferFrom(msg.sender, address(this), _tokenId);
        }

        string memory username = usernames[msg.sender];
        uint256 requestId = mirroredTokenRequestCount[username];

        if (_isERC20) {
            string memory name = string(
                abi.encodePacked("Mirrored ", ERC20(_token).name())
            );
            string memory symbol = string(
                abi.encodePacked("m", ERC20(_token).symbol())
            );
            address mirroredToken = address(
                new MirroredERC20(
                    name,
                    symbol,
                    _token,
                    requestId,
                    username,
                    address(this)
                )
            );
            mirroredERC20Tokens[username][requestId] = mirroredToken;
            MirroredERC20(mirroredToken).mint(msg.sender, _amount);

            emit MirroredERC20Minted(username, ERC20(_token).symbol(), _amount);
        } else {
            string memory name = string(
                abi.encodePacked("Mirrored ", ERC721(_token).name())
            );
            string memory symbol = string(
                abi.encodePacked("m", ERC721(_token).symbol())
            );
            address mirroredToken = address(
                new MirroredERC721(
                    name,
                    symbol,
                    _token,
                    requestId,
                    username,
                    address(this)
                )
            );
            mirroredERC721Tokens[username][requestId] = mirroredToken;
            underlyingERC721TokenIds[username][requestId] = _tokenId;
            MirroredERC721(mirroredToken).mint(msg.sender, 0);

            emit MirroredERC721Minted(
                username,
                ERC721(_token).name(),
                ERC721(_token).symbol()
            );
        }

        mirroredTokenRequestCount[username]++;

        mfaManager.setMFAProviders(username, requestId, _mfaProviders);
    }

    function unlockAsset(
        address _token,
        uint256 _amount,
        uint256 _requestId,
        bool _isERC20
    ) public {
        string memory username = usernames[msg.sender];
        uint256 timeLimit = 600; // 10 minutes

        for (
            uint256 i = 0;
            i <
            mfaManager.getVaultRequestMFAProviderCount(username, _requestId);
            ++i
        ) {
            IMFA mfaProvider = IMFA(
                mfaManager.getVaultRequestMFAProviders(username, _requestId, i)
            );
            IMFA.MFAData memory mfaData = mfaProvider.getMFAData(
                username,
                _requestId
            );
            require(mfaData.success, "MFA verification failed");
            require(
                mfaData.timestamp >= block.timestamp - timeLimit,
                "MFA data expired"
            );
        }

        if (_isERC20) {
            address mirroredToken = mirroredERC20Tokens[username][_requestId];
            require(
                mirroredToken != address(0),
                "Mirrored token does not exist"
            );
            require(
                MirroredERC20(mirroredToken).balanceOf(msg.sender) >= _amount,
                "Insufficient mirrored token balance"
            );
            require(
                IERC20(_token).balanceOf(address(this)) >= _amount,
                "Insufficient balance in contract"
            );

            MirroredERC20(mirroredToken).burnFrom(msg.sender, _amount);
            IERC20(_token).transfer(msg.sender, _amount);
        } else {
            address mirroredToken = mirroredERC721Tokens[username][_requestId];
            require(
                mirroredToken != address(0),
                "Mirrored token does not exist"
            );
            require(
                MirroredERC721(mirroredToken).ownerOf(0) == msg.sender,
                "Caller is not owner of mirrored token"
            );

            uint256 tokenId = underlyingERC721TokenIds[username][_requestId];
            require(
                IERC721(_token).ownerOf(tokenId) == address(this),
                "Contract is not owner of token"
            );

            MirroredERC721(mirroredToken).burn(0);
            IERC721(_token).transferFrom(address(this), msg.sender, tokenId);
        }
    }

    function batchLockAndSetMFA(
        address _token,
        uint256 _amount,
        uint256 _tokenId,
        bool _isERC20,
        address[] memory _mfaProviders,
        uint256 _passwordHash
    ) external {
        string memory username = usernames[msg.sender];
        uint256 requestId = mirroredTokenRequestCount[username];

        lockAsset(_token, _amount, _tokenId, _isERC20, _mfaProviders);

        bool haszkVaultMFA = false;
        for (uint256 i = 0; i < _mfaProviders.length; ++i) {
            if (_mfaProviders[i] == mfaManager.getZkVaultMFAAddress()) {
                haszkVaultMFA = true;
                break;
            }
        }

        if (haszkVaultMFA) {
            IzkVaultMFA(mfaManager.getZkVaultMFAAddress())
                .setRequestPasswordHash(username, requestId, _passwordHash);
        }
    }

    function batchUnlockAndVerifyMFA(
        address _token,
        uint256 _amount,
        uint256 _requestId,
        bool _isERC20,
        uint256 _timestamp,
        ProofParameters memory _zkpParams,
        MFAProviderData[] memory _mfaProviderData
    ) external {
        string memory username = usernames[msg.sender];

        require(
            mfaManager.verifyMFA(
                username,
                _requestId,
                _timestamp,
                _zkpParams,
                _mfaProviderData
            ),
            "MFA verification failed"
        );

        unlockAsset(_token, _amount, _requestId, _isERC20);
    }
}

contract MirroredERC20 is ERC20 {
    address public underlyingAsset;
    uint256 public requestId;
    string public username;
    mapping(address => bool) private _approvalCalled;
    address public owner;

    constructor(
        string memory name,
        string memory symbol,
        address _underlyingAsset,
        uint256 _requestId,
        string memory _username,
        address _owner
    ) ERC20(name, symbol) {
        underlyingAsset = _underlyingAsset;
        requestId = _requestId;
        username = _username;
        owner = _owner;
    }

    function mint(address to, uint256 amount) public {
        require(msg.sender == owner, "Only the owner can mint tokens");
        _mint(to, amount);
    }

    function burnFrom(address account, uint256 amount) public {
        require(msg.sender == owner, "Only the owner can burn tokens");
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
    address public owner;

    constructor(
        string memory name,
        string memory symbol,
        address _underlyingAsset,
        uint256 _requestId,
        string memory _username,
        address _owner
    ) ERC721(name, symbol) {
        underlyingAsset = _underlyingAsset;
        requestId = _requestId;
        username = _username;
        owner = _owner;
    }

    function mint(address to, uint256 tokenId) public {
        require(msg.sender == owner, "Only owner can mint tokens");
        _safeMint(to, tokenId);
    }

    function burn(uint256 tokenId) public {
        require(msg.sender == owner, "Only owner can burn tokens");
        _burn(tokenId);
    }

    function setApprovalForAll(address to, bool approval)
        public
        virtual
        override
    {
        require(
            !_approvalCalled[msg.sender],
            "Approval can only be called once"
        );
        _approvalCalled[msg.sender] = true;
        super.setApprovalForAll(to, approval);
    }

    function exists(uint256 tokenId) public view returns (bool) {
        return exists(tokenId);
    }
}
