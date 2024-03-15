pragma solidity ^0.8.7;

contract ExternalSignerMFA {
    address public externalSigner;

    struct MFAData {
        bool success;
        uint256 timestamp;
    }

    mapping(uint256 => MFAData) public MFARequestData;

    constructor(address _externalSigner) {
        externalSigner = _externalSigner;
    }

    function setValue(
        uint256 requestId,
        uint256 timestamp,
        string memory message, // Accept a string message
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        uint256 timeLimit = 120;
        require(timestamp <= block.timestamp);
        require(timestamp >= block.timestamp - timeLimit);

        // Convert the message back to requestId, success, and timestamp
        (
            uint256 parsedRequestId,
            bool parsedSuccess,
            uint256 parsedTimestamp
        ) = parseMessage(message);

        // Check if the parsed values match the provided values
        require(
            parsedRequestId == requestId &&
                parsedSuccess == true &&
                parsedTimestamp == timestamp,
            "Invalid message"
        );

        bytes32 hash = hashMessage(message);
        require(
            ecrecover(hash, v, r, s) == externalSigner,
            "Invalid signature"
        );

        MFARequestData[requestId].success = true;
        MFARequestData[requestId].timestamp = block.timestamp;
    }

    function getMFAData(uint256 _requestID)
        external
        view
        returns (MFAData memory)
    {
        return MFARequestData[_requestID];
    }

    // Helper function to parse the concatenated message
    function parseMessage(string memory message)
        public
        pure
        returns (
            uint256,
            bool,
            uint256
        )
    {
        bytes memory messageBytes = bytes(message);
        uint256 index = 0;

        // Parse requestId
        uint256 requestId;
        while (index < messageBytes.length && messageBytes[index] != "-") {
            requestId =
                requestId *
                10 +
                uint256(uint8(messageBytes[index])) -
                48;
            index++;
        }
        index++; // Skip the '-'

        // Parse success
        bool success;
        if (messageBytes[index] == "t") {
            success = true;
        } else {
            success = false;
        }
        while (index < messageBytes.length && messageBytes[index] != "-") {
            index++; // Skip until the next '-'
        }
        index++; // Skip the '-'

        // Parse timestamp
        uint256 timestamp;
        while (index < messageBytes.length) {
            timestamp =
                timestamp *
                10 +
                uint256(uint8(messageBytes[index])) -
                48;
            index++;
        }

        return (requestId, success, timestamp);
    }

    function returnTimestamp() public view returns (uint256) {
        return block.timestamp;
    }

    function ecr(
        bytes32 msgh,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public pure returns (address sender) {
        return ecrecover(msgh, v, r, s);
    }

    function hashMessage(string memory message) public pure returns (bytes32) {
        // Prefix the message according to Ethereum signature standard
        string memory prefix = "\x19Ethereum Signed Message:\n";
        uint256 length = bytes(message).length;
        string memory messageLength = uintToString(length);
        string memory prefixedMessage = string(
            abi.encodePacked(prefix, messageLength, message)
        );

        // Hash the prefixed message using Keccak-256
        return keccak256(abi.encodePacked(prefixedMessage));
    }

    // Helper function to convert uint to string
    function uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
