// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

interface IValueOracle {
    function updateValue(address token) external;
    function getCurrentValue(address token, uint256 balance) external view returns (uint256);
}