// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

struct LockInfo {
    uint256 interval;
    uint256 reward;   
}

struct AddressParams {
    address vault;
    address owner;
    address spender;
    address sender;
    address recipient;
}

interface IVaultRegistry {

    function balanceOf(AddressParams memory addresses) external view returns (uint256);
    function transfer(AddressParams memory addresses, uint256 amount) external returns (bool);
    function allowance(AddressParams memory addresses) external view returns (uint256);
    function approve(AddressParams memory addresses, uint256 amount) external returns (bool);
    function burn(AddressParams memory addresses, uint256 amount) external returns (bool);
    function transferFrom(AddressParams memory addresses, uint256 amount) external returns (bool);
    function lockCount() external view returns (uint256);
    function lockInfo(uint256 index) external view returns (LockInfo memory);
}