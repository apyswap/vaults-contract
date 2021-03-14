// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "./interfaces/IVaultRegistry.sol";
import "./interfaces/ITokenRegistry.sol";

contract Vault is IERC20, Initializable {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    IVaultRegistry private _vaultRegistry;
    ITokenRegistry private _tokenRegistry;
    uint256 public lockedSince;
    uint256 public lockedUntil;
    uint256 public lockedValue;

    uint256 private _totalSupply;
    mapping(address => uint256) private _accountShare;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 constant private MAX_LOCKED_VALUE = 1000 ether; // Actually it is 1000 USDT
    uint256 constant private TOTAL_SHARE = 1 ether;
    uint256 constant private EMERGENCY_INTERVAL = 100 days;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() public {
        // Empty constructor, use initialize
    }

    function initialize(address shareOwner, IVaultRegistry vaultRegistry, ITokenRegistry tokenRegistry) external initializer {
        _mint(shareOwner, TOTAL_SHARE);

        _vaultRegistry = vaultRegistry;
        _tokenRegistry = tokenRegistry;
    }

    modifier locked() {
        require(lockedUntil >= block.timestamp, "!locked");
        _;
    }

    modifier neverlocked() {
        require(lockedUntil == 0, "!neverlocked");
        _;
    }

    modifier notLocked() {
        require(lockedUntil < block.timestamp, "locked");
        _;
    }

    modifier shareOwner() {
        require(_balanceOf(msg.sender) == TOTAL_SHARE, "!share owner");
        _;
    }

    modifier registryManager() {
        require(msg.sender == _vaultRegistry.manager(), "!registry manager");
        _;
    }

    receive() external payable {}

    function totalSupply() external override view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external override view returns (uint256) {
        return _balanceOf(account);
    }

    function _balanceOf(address account) internal view returns (uint256) {
        return _accountShare[account];
    }

    function transfer(address recipient, uint256 amount) external locked override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) external override view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external locked override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external locked override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount, "!allowance"));
        return true;
    }

    function totalValue() external view returns (uint256) {
        return _totalValue();
    }

    function _totalValue() internal view returns (uint256) {
        uint256 value = 0;
        // Calculate ETH equivalent
        value = value.add(_tokenRegistry.tokenValue(_tokenRegistry.WETH(), address(this).balance));
        // Add value of other tokens
        uint256 index = _tokenRegistry.tokenCount();
        while (index > 0) {
            index -= 1;
            address tokenAddress = _tokenRegistry.tokenAddress(index);
            value = value.add(_tokenRegistry.tokenValue(tokenAddress, _tokenBalance(tokenAddress)));
        }
        return value;
    }

    // Return token balance for the vault contract
    function _tokenBalance(address token) internal view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function lock(uint256 lockTypeId) external neverlocked {
        LockInfo memory lockInfo = _vaultRegistry.lockInfo(lockTypeId);
        lockedSince = block.timestamp;
        lockedUntil = block.timestamp + lockInfo.interval;
        lockedValue = Math.max(_totalValue(), MAX_LOCKED_VALUE);
        _vaultRegistry.getLockReward(lockTypeId, lockedValue);
    }

    // Emergency unlock, all liquidity is instantly withdrawable, but reward is lost
    function unlock() external locked shareOwner {
        // Mark unlocked
        lockedUntil = block.timestamp - 1;

        // Remove all the rewards
        IERC20 rewardContract = _vaultRegistry.tokenReward();
        rewardContract.safeTransfer(address(_vaultRegistry), rewardContract.balanceOf(address(this)));
    }

    // Withdraw tokens according to the user's share, burn ownership token
    function withdraw() external notLocked {
        uint256 share = _balanceOf(msg.sender);
        if (share == 0) {
            return;
        }
        // Burn ownership token
        _burn(msg.sender, share);

        // Transfer ETH
        _safeEthWithdraw(msg.sender, _calculateShareBalanceAfterBurn(share, address(this).balance));

        // Transfer tokens
        // Number of tokens is controlled by the TokenRegistry owner be careful not to increase it, otherwise this transaction can fail
        uint256 index = _tokenRegistry.tokenCount();
        while (index > 0) {
            index -= 1;
            IERC20 tokenContract = IERC20(_tokenRegistry.tokenAddress(index));
            tokenContract.safeTransfer(msg.sender, _calculateShareBalanceAfterBurn(share, tokenContract.balanceOf(address(this))));
        }

        // Transfer reward tokens
        IERC20 rewardContract = _vaultRegistry.tokenReward();
        rewardContract.safeTransfer(msg.sender, _calculateShareBalanceAfterBurn(share, rewardContract.balanceOf(address(this))));
    }

    function emergencyEthWithdraw(uint256 amount) external registryManager {
        require(_totalSupply == 0 || block.timestamp > _vaultRegistry.finishTime() + EMERGENCY_INTERVAL, "!emergency");
        _safeEthWithdraw(msg.sender, amount);
    }

    function emergencyWithdraw(address token, uint256 amount) external registryManager {
        require(_totalSupply == 0 || block.timestamp > _vaultRegistry.finishTime() + EMERGENCY_INTERVAL, "!emergency");
        IERC20 tokenContract = IERC20(token);
        tokenContract.safeTransfer(msg.sender, amount);
    }

    function _calculateShareBalanceAfterBurn(uint256 share, uint256 balance) internal view returns (uint256) {
        // We add share to _totalSupply because this function gets called after the share is burned
        return balance.mul(share).div(_totalSupply.add(share));
    }

    function _safeEthWithdraw(address to, uint256 amount) internal {
        (bool success, ) = to.call{ value: amount }("");
        require(success, "eth withdraw");
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "transfer from zero");
        require(recipient != address(0), "transfer to zero");

        _accountShare[sender] = _accountShare[sender].sub(amount, "transfer amount");
        _accountShare[recipient] = _accountShare[recipient].add(amount);

        _vaultRegistry.updateOwnership(sender, recipient);

        emit Transfer(sender, recipient, amount);
    }
    
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "approve from zero");
        require(spender != address(0), "approve to zero");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "mint to zero");

        _totalSupply = _totalSupply.add(amount);
        _accountShare[account] = _accountShare[account].add(amount);

        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "burn from zero");

        _accountShare[account] = _accountShare[account].sub(amount, "burn amount");
        _totalSupply = _totalSupply.sub(amount);

        _vaultRegistry.updateOwnership(account, address(0));

        emit Transfer(account, address(0), amount);
    }
}