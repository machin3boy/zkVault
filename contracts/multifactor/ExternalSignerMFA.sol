// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract ExternalSignerMFA {
    address public externalSigner;

    struct MFAData {
        bool success;
        uint256 timestamp;
    }

    mapping(string => mapping(uint256 => MFAData)) public MFARequestData;

    constructor(address _externalSigner) {
        externalSigner = _externalSigner;
    }

    function setValue(
        string memory username,
        uint256 requestId,
        uint256 timestamp,
        string memory message,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        uint256 timeLimit = 600;
        require(timestamp <= block.timestamp);
        require(timestamp >= block.timestamp - timeLimit);

        (
            string memory parsedUsername,
            uint256 parsedRequestId,
            uint256 parsedTimestamp
        ) = parseMessage(message);

        require(
            keccak256(abi.encodePacked(parsedUsername)) ==
                keccak256(abi.encodePacked(username)) &&
                parsedRequestId == requestId &&
                parsedTimestamp == timestamp,
            "Invalid message"
        );

        bytes32 hash = hashMessage(message);
        require(
            ecrecover(hash, v, r, s) == externalSigner,
            "Invalid signature"
        );

        MFARequestData[username][requestId].success = true;
        MFARequestData[username][requestId].timestamp = block.timestamp;
    }

    function getMFAData(string memory username, uint256 requestId)
        external
        view
        returns (MFAData memory)
    {
        return MFARequestData[username][requestId];
    }

    // Helper function to parse the concatenated message
    function parseMessage(string memory message)
        public
        pure
        returns (
            string memory,
            uint256,
            uint256
        )
    {
        bytes memory messageBytes = bytes(message);
        uint256 index = 0;

        // Parse username
        string memory username = parseString(messageBytes, index);
        index += bytes(username).length + 1; // Skip the '-'

        // Parse requestId
        uint256 requestId = parseUint(messageBytes, index);
        index += getDigitsCount(requestId) + 1; // Skip the '-'

        // Parse timestamp
        uint256 timestamp = parseUint(messageBytes, index);

        return (username, requestId, timestamp);
    }

    // Helper function to parse a string from bytes
    function parseString(bytes memory data, uint256 startIndex)
        internal
        pure
        returns (string memory)
    {
        uint256 endIndex = startIndex;
        while (endIndex < data.length && data[endIndex] != "-") {
            endIndex++;
        }
        bytes memory stringBytes = new bytes(endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            stringBytes[i - startIndex] = data[i];
        }
        return string(stringBytes);
    }

    // Helper function to parse a uint256 from bytes
    function parseUint(bytes memory data, uint256 startIndex)
        internal
        pure
        returns (uint256)
    {
        uint256 value = 0;
        uint256 index = startIndex;
        bool isZero = true;
        while (index < data.length && data[index] != "-") {
            if (data[index] != "0") {
                isZero = false;
            }
            value = value * 10 + uint256(uint8(data[index])) - 48;
            index++;
        }
        if (isZero && index > startIndex) {
            return 0;
        }
        return value;
    }

    // Helper function to get the count of digits in a uint256
    function getDigitsCount(uint256 value) internal pure returns (uint256) {
        uint256 count = 0;
        while (value != 0) {
            count++;
            value /= 10;
        }
        return count;
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
        string memory prefix = "\x19Ethereum Signed Message:\n";
        uint256 length = bytes(message).length;
        string memory messageLength = uintToString(length);
        string memory prefixedMessage = string(
            abi.encodePacked(prefix, messageLength, message)
        );

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
