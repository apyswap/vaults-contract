// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "./interfaces/IVaultTokenRegistry.sol";

contract Vault is IERC20 {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    IVaultTokenRegistry _tokenRegistry;
    uint256 public lockedUntil;
    uint256 public lockedValue;

    uint256 constant MAX_LOCKED_VALUE = 1000 ether; // Actually it is 1000 USDT
    uint256 constant TOTAL_SHARE = 1 ether;

    constructor(IVaultTokenRegistry tokenRegistry) public {
        lockedUntil = 0;
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

    modifier shareOwner() {
        require(_balanceOf(msg.sender) == TOTAL_SHARE, "!shareOwner");
        _;
    }

    receive() external payable {}

    function totalSupply() external override view returns (uint256) {
        return TOTAL_SHARE;
    }

    function balanceOf(address account) external override view returns (uint256) {
        return _balanceOf(account);
    }

    function _balanceOf(address account) internal view returns (uint256) {
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

    function valueOf() external view returns (uint256) {
        return _valueOf();
    }

    function _valueOf() internal view returns (uint256) {
        uint256 value = 0;
        // Calculate ETH equivalent
        value = value.add(_tokenRegistry.tokenValue(_tokenRegistry.WETH(), address(this).balance));
        // Add value of other tokens from _tokens
        for (uint256 index = _tokenRegistry.tokensCount() - 1; index >= 0; index--) {
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
        LockInfo memory lockInfo = _tokenRegistry.lockInfo(lockTypeId);
        lockedUntil = block.timestamp + lockInfo.interval;
        lockedValue = Math.max(_valueOf(), MAX_LOCKED_VALUE);
    }

    // Withdraw tokens according to the user's share, burn ownership token
    function withdraw() external {
        uint256 share = _balanceOf(msg.sender);
        if (share == 0) {
            return;
        }
        // Burn ownership token
        AddressParams memory addresses = AddressParams({
            vault: address(this),
            owner: address(0),
            spender: address(0),
            sender: msg.sender,
            recipient: address(0)
        });
        require(_tokenRegistry.burn(addresses, share), "!burn");

        // Transfer ETH
        _safeEthWithdraw(msg.sender, _calculateShareBalance(share, address(this).balance));

        // Transfer tokens
        for (uint256 index = _tokenRegistry.tokensCount() - 1; index >= 0; index--) {
            IERC20 tokenContract = IERC20(_tokenRegistry.tokenAddress(index));
            tokenContract.safeTransfer(msg.sender, _calculateShareBalance(share, tokenContract.balanceOf(address(this))));
        }
    }

    function _calculateShareBalance(uint256 share, uint256 balance) internal pure returns (uint256) {
        return balance.mul(share).div(TOTAL_SHARE);
    }

    function _safeEthWithdraw(address to, uint256 amount) internal {
        (bool success, ) = to.call{ value: amount }("");
        require(success, "!ethWithdraw");
    }
}