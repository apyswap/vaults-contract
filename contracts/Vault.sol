// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import "./interfaces/IVaultTokenRegistry.sol";

contract Vault is IERC20Upgradeable, Initializable {

    IVaultTokenRegistry _tokenRegistry;
    uint256 public lockedUntil;
    uint256 public lockedValue;

    uint256 constant MAX_LOCKED_VALUE = 1000 ether;

    constructor() public {
        lockedUntil = 0;
    }

    modifier locked() {
        require(lockedUntil >= block.timestamp, "!locked");
        _;
    }

    modifier neverlocked() {
        require(lockedUntil == 0, "!neverlocked");
        _;
    }

    receive() external payable {}

    function initialize(IVaultTokenRegistry tokenRegistry) external initializer {
        _tokenRegistry = tokenRegistry;
    }

    function totalSupply() external override view returns (uint256) {
        return 1 ether;
    }

    function balanceOf(address account) external override view returns (uint256) {
        return _tokenRegistry.balanceOf(address(this), account);
    }

    function transfer(address recipient, uint256 amount) external locked override returns (bool) {
        return _tokenRegistry.transfer(address(this), msg.sender, recipient, amount);
    }

    function allowance(address owner, address spender) external override view returns (uint256) {
        return _tokenRegistry.allowance(address(this), owner, spender);
    }

    function approve(address spender, uint256 amount) external locked override returns (bool) {
        return _tokenRegistry.approve(address(this), msg.sender, spender, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external locked override returns (bool) {
        return _tokenRegistry.transferFrom(address(this), msg.sender, sender, recipient, amount);
    }

    function valueOf(address[] calldata tokens) external view returns (uint256) {
        return _tokenRegistry.valueOf(address(this).balance, tokens);
    }

    function lock(address[] calldata tokens, uint256 lockTypeId) external neverlocked {
        LockInfo memory lockInfo = _tokenRegistry.lockInfo(lockTypeId);
        lockedUntil = block.timestamp + lockInfo.interval;
        lockedValue = MathUpgradeable.max(_tokenRegistry.valueOf(address(this).balance, tokens), MAX_LOCKED_VALUE);
    }

    // Withdraw tokens according to the user's share, burn ownership token
    function withdraw(address[] calldata tokens) external {
        // TODO: Implementation
    }
}