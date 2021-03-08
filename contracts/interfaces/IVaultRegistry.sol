// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

struct LockInfo {
    uint256 interval;
    uint256 reward;   
}

interface IVaultRegistry {

    function tokenReward() external view returns (IERC20);
    function startTime() external view returns (uint256);
    function finishTime() external view returns (uint256);

    function lockCount() external view returns (uint256);
    function lockInfo(uint256 index) external view returns (LockInfo memory);

    function updateOwnership(address sender, address recipient) external;
    function getLockReward(uint256 lockIndex, uint256 value) external;
}