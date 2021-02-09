// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

struct LockInfo {
    uint256 interval;
    uint256 reward;   
}

interface IVaultTokenRegistry {
    function balanceOf(address vault, address account) external view returns (uint256);
    function transfer(address vault, address sender, address recipient, uint256 amount) external returns (bool);
    function allowance(address vault, address owner, address spender) external view returns (uint256);
    function approve(address vault, address owner, address spender, uint256 amount) external returns (bool);
    function transferFrom(address vault, address spender, address sender, address recipient, uint256 amount) external returns (bool);
    function valueOf(uint256 ethBalance, address[] calldata tokens) external view returns (uint256);
    function lockCount() external view returns (uint256);
    function lockInfo(uint256 index) external view returns (LockInfo memory);
}