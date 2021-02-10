// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "./interfaces/IVaultTokenRegistry.sol";

contract Vault is IERC20, Initializable {

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
        AddressParams memory addresses = AddressParams({
            vault: address(this),
            owner: account,
            spender: address(0),
            sender: address(0),
            recipient: address(0)
        });
        return _tokenRegistry.balanceOf(addresses);
    }

    function transfer(address recipient, uint256 amount) external locked override returns (bool) {
        AddressParams memory addresses = AddressParams({
            vault: address(this),
            owner: address(0),
            spender: address(0),
            sender: msg.sender,
            recipient: recipient
        });
        return _tokenRegistry.transfer(addresses, amount);
    }

    function allowance(address owner, address spender) external override view returns (uint256) {
        AddressParams memory addresses = AddressParams({
            vault: address(this),
            owner: owner,
            spender: spender,
            sender: address(0),
            recipient: address(0)
        });
        return _tokenRegistry.allowance(addresses);
    }

    function approve(address spender, uint256 amount) external locked override returns (bool) {
        AddressParams memory addresses = AddressParams({
            vault: address(this),
            owner: msg.sender,
            spender: spender,
            sender: address(0),
            recipient: address(0)
        });
        return _tokenRegistry.approve(addresses, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external locked override returns (bool) {
        AddressParams memory addresses = AddressParams({
            vault: address(this),
            owner: sender,
            spender: msg.sender,
            sender: sender,
            recipient: recipient
        });
        return _tokenRegistry.transferFrom(addresses, amount);
    }

    function valueOf(address[] calldata tokens) external view returns (uint256) {
        return _tokenRegistry.valueOf(address(this).balance, tokens);
    }

    function lock(address[] calldata tokens, uint256 lockTypeId) external neverlocked {
        LockInfo memory lockInfo = _tokenRegistry.lockInfo(lockTypeId);
        lockedUntil = block.timestamp + lockInfo.interval;
        lockedValue = Math.max(_tokenRegistry.valueOf(address(this).balance, tokens), MAX_LOCKED_VALUE);
    }

    // Withdraw tokens according to the user's share, burn ownership token
    function withdraw(address[] calldata tokens) external {
        // TODO: Implementation
    }
}