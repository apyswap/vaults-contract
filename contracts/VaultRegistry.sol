// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/SafeCast.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./interfaces/IVaultRegistry.sol";
import "./interfaces/ITokenRegistry.sol";
import "./Vault.sol";

contract VaultRegistry is Ownable, IVaultRegistry {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;
    using Clones for address;

    uint256 private _maxLockedValue = 1000 ether; // Actually it is 1000 USDT

    LockInfo[] private _lockInfo;

    ITokenRegistry public tokenRegistry;

    address public vaultLogic;

    IERC20 public override tokenReward;
    uint256 public rewardTotal;
    uint256 public override rewardAvailable;

    uint256 public override startTime;
    uint256 public override finishTime;

    EnumerableSet.AddressSet private _vaults;
    mapping(address => EnumerableSet.AddressSet) private _accountVaults;

    event VaultCreated(address indexed vaultAddress);
    event RewardSent(address to, uint256 value);

    constructor(ITokenRegistry tokenRegistry_, address vaultLogic_, uint256 startTime_, uint256 finishTime_) public {

        tokenRegistry = tokenRegistry_;
        vaultLogic = vaultLogic_;
        startTime = startTime_;
        finishTime = finishTime_;
    }

    modifier onlyVault() {
        require(_vaults.contains(msg.sender), "!vault");
        _;
    }

    function addLock(uint256 interval, uint256 reward) external onlyOwner {
        _lockInfo.push(LockInfo({interval: interval, reward: reward}));
    }
    function updateLock(uint256 index, uint256 interval, uint256 reward) external onlyOwner {
        _lockInfo[index].interval = interval;
        _lockInfo[index].reward = reward;
    }
    function deleteLock(uint256 index) external onlyOwner {
        while (index < _lockInfo.length - 1) {  // Array is small and admin-managed, so this loop is safe
            _lockInfo[index] = _lockInfo[index + 1]; // We have to move remaining elements because the order is important
            index++;
        }
        _lockInfo.pop();
    }

    function createVault() public {
        require(block.timestamp > startTime && block.timestamp < finishTime, "!active");
        Vault vault = Vault(payable(vaultLogic.clone()));
        vault.initialize(msg.sender, this, tokenRegistry);
        _vaults.add(address(vault));
        _accountVaults[msg.sender].add(address(vault));
        emit VaultCreated(address(vault));
    }

    function setReward(IERC20 token) external onlyOwner {
        tokenReward = token;
    }

    function setRewardValue(uint256 amount) external onlyOwner {
        if (amount >= rewardTotal) {
            rewardAvailable = rewardAvailable.add(amount.sub(rewardTotal));
        } else {
            require(rewardTotal.sub(amount) < rewardAvailable, 'Negative reward');
            rewardAvailable = rewardAvailable.sub(rewardTotal.sub(amount));
        }
        rewardTotal = amount;
    }

    function subReward(uint256 amount) external override onlyVault {
        rewardAvailable = rewardAvailable.sub(amount);
    }

    function withdrawReward(uint256 amount) external onlyOwner {
        tokenReward.safeTransfer(msg.sender, amount);
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

    function maxLockedValue() external override view returns (uint256) {
        return _maxLockedValue;
    }

    function setMaxLockedValue(uint256 value) external onlyOwner {
        _maxLockedValue = value;
    }

    function updateOwnership(address sender, address recipient) external override onlyVault {
        IERC20 vault_ = IERC20(msg.sender);
        if (sender != address(0) && vault_.balanceOf(sender) == 0) {
            _accountVaults[sender].remove(address(vault_));
        }
        if (recipient != address(0) && vault_.balanceOf(recipient) > 0) {
            _accountVaults[recipient].add(address(vault_));
        }
    }

    function sendReward(address user, uint256 value) external override onlyVault {
        uint256 tokenAmount = tokenRegistry.valueToTokens(address(tokenReward), value);
        tokenReward.safeTransfer(user, tokenAmount);
        emit RewardSent(user, tokenAmount);
    }

    function manager() external override view returns (address) {
        return owner();
    }
}
