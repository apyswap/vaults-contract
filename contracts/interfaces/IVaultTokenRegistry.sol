// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

struct LockInfo {
    uint256 interval;
    uint256 reward;   
}

struct TokenInfo {
    address contractAddress;
    string name;
    string symbol;
    uint8 decimals;
    uint256 balance;
}

struct AddressParams {
    address vault;
    address owner;
    address spender;
    address sender;
    address recipient;
}

interface IVaultTokenRegistry {

    function WETH() external pure returns (address);
    function USDT() external pure returns (address);

    function balanceOf(AddressParams memory addresses) external view returns (uint256);
    function transfer(AddressParams memory addresses, uint256 amount) external returns (bool);
    function allowance(AddressParams memory addresses) external view returns (uint256);
    function approve(AddressParams memory addresses, uint256 amount) external returns (bool);
    function burn(AddressParams memory addresses, uint256 amount) external returns (bool);
    function transferFrom(AddressParams memory addresses, uint256 amount) external returns (bool);
    function lockCount() external view returns (uint256);
    function lockInfo(uint256 index) external view returns (LockInfo memory);

    function uniswapFactory() external view returns (IUniswapV2Factory);

    function tokenValue(address token_, uint256 balance) external view returns (uint256);
    function tokensCount() external view returns (uint256);
    function tokenAddress(uint256 index) external view returns (address);
}