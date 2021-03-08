// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

struct TokenInfo {
    address contractAddress;
    string name;
    string symbol;
    uint8 decimals;
}

interface ITokenRegistry {
    function WETH() external view returns (address);
    function USDT() external view returns (address);
    function tokenValue(address token_, uint256 balance) external view returns (uint256);
    function tokenCount() external view returns (uint256);
    function tokenAddress(uint256 index) external view returns (address);
}