// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

interface IVaultTokenRegistry {
    function balanceOf(address vault, address account) external view returns (uint256);
    function transfer(address vault, address recipient, uint256 amount) external returns (bool);
    function allowance(address vault, address owner, address spender) external view returns (uint256);
    function approve(address vault, address spender, uint256 amount) external returns (bool);
    function transferFrom(address vault, address sender, address recipient, uint256 amount) external returns (bool);
}