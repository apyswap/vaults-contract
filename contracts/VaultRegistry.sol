// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./Vault.sol";
import "./interfaces/IVaultRegistry.sol";

contract VaultRegistry is Ownable, IVaultRegistry {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    LockInfo[] private _lockInfo;

    ITokenRegistry public tokenRegistry;

    IERC20 public override tokenReward;
    uint256 public rewardTotal;
    uint256 public rewardAvailable; 

    uint256 public override startTime;
    uint256 public override finishTime;

    EnumerableSet.AddressSet private _vaults;
    mapping(address => EnumerableSet.AddressSet) private _accountVaults;
    
    constructor(ITokenRegistry tokenRegistry_, uint256 startTime_, uint256 finishTime_) public {

        tokenRegistry = tokenRegistry_;
        startTime = startTime_;
        finishTime = finishTime_;

        _lockInfo.push(LockInfo({interval: 1 minutes, reward: 0}));
        _lockInfo.push(LockInfo({interval: 5 minutes, reward: 10}));
        _lockInfo.push(LockInfo({interval: 10 minutes, reward: 20}));
    }

    function createVault() public {
        require(block.timestamp > startTime && block.timestamp < finishTime, "!active");
        Vault vault = new Vault(msg.sender, this, tokenRegistry);
        _vaults.add(address(vault));
        _accountVaults[msg.sender].add(address(vault));
    }

    function setReward(IERC20 token, uint256 amount) external onlyOwner {
        tokenReward = token;
        token.safeTransferFrom(msg.sender, address(this), amount);
        rewardTotal = rewardTotal.add(amount);
        rewardAvailable = rewardAvailable.add(amount);
    }

    function vaultCount(address user) external view returns (uint256) {
        return _accountVaults[user].length();
    }

    function vault(address user, uint256 index) external view returns (address) {
        return _accountVaults[user].at(index);
    }

    function globalVaultCount() external view returns (uint256) {
        return _vaults.length();
    }

    function globalVault(uint256 index) external view returns (address) {
        return _vaults.at(index);
    }

    function lockCount() external override view returns (uint256) {
        return _lockInfo.length;
    }

    function lockInfo(uint256 index) external override view returns (LockInfo memory) {
        return _lockInfo[index];
    }

    function updateOwnership(address sender, address recipient) external override {
        require(_vaults.contains(msg.sender), "!vault");
        IERC20 vault_ = IERC20(msg.sender);
        if (sender != address(0) && vault_.balanceOf(sender) == 0) {
            _accountVaults[sender].remove(address(vault_));
        }
        if (recipient != address(0) && vault_.balanceOf(recipient) > 0) {
            _accountVaults[recipient].add(address(vault_));
        }
    }

    function getLockReward(uint256 lockIndex, uint256 value) external override {
        require(_vaults.contains(msg.sender), "!vault");
        uint256 reward = value.mul(_lockInfo[lockIndex].reward).div(100);
        rewardAvailable = rewardAvailable.sub(reward);
        tokenReward.safeTransfer(msg.sender, reward);
    }
}