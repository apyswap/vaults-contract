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

struct TokenInfo {
    address contractAddress;
    string name;
    string symbol;
    uint8 decimals;
    uint256 balance;
}

struct TokenValueInfo {
    uint256 timestamp;
    uint256 cumulativePrice;
}

interface IERC20Ex is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

contract Vault is IERC20 {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    IVaultTokenRegistry _tokenRegistry;
    uint256 public lockedUntil;
    uint256 public lockedValue;
    EnumerableSet.AddressSet private _tokens;
    mapping( address => TokenValueInfo ) private _tokenValues;

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
        value = value.add(_tokenValue(WETH, address(this).balance));
        // Add value of other tokens from _tokens
        for (uint256 index = 0; index < _tokens.length(); index++) {
            address tokenAddress = _tokens.at(index);
            value = value.add(_tokenValue(tokenAddress, _tokenBalance(tokenAddress)));
        }
        return value;
    }

    // Return token balance for the vault contract
    function _tokenBalance(address token) internal view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function _tokenValue(address token, uint256 balance) internal view returns (uint256) {
        if (balance == 0) {
            return 0;
        }
        if (token == USDT) {
            return balance;
        }

        TokenValueInfo storage pastInfo = _tokenValues[token];
        if (pastInfo.cumulativePrice == 0) {
            return 0;
        }

        uint256 cumulativePrice = _getLastCumulativePrice(token);
        if (cumulativePrice == 0 || cumulativePrice <= pastInfo.cumulativePrice) {
            return 0;
        }
        if (block.timestamp <= pastInfo.timestamp) {
            return 0;
        }

        return cumulativePrice.sub(pastInfo.cumulativePrice).mul(balance).div(block.timestamp.sub(pastInfo.timestamp));
    }

    function _getLastCumulativePrice(address token) internal view returns (uint256) {
        IUniswapV2Pair pair = IUniswapV2Pair(_tokenRegistry.uniswapFactory().getPair(token, WETH));
        if (address(pair) == address(0)) {
            // Pair does not exist
            return 0;
        }
        if (pair.token0() == token) {
            return pair.price0CumulativeLast();
        }
        if (pair.token1() == token) {
            return pair.price1CumulativeLast();
        }
        // Something went wrong, return 0
        return 0;
    }

    function lock(uint256 lockTypeId) external neverlocked {
        LockInfo memory lockInfo = _tokenRegistry.lockInfo(lockTypeId);
        lockedUntil = block.timestamp + lockInfo.interval;
        lockedValue = Math.max(_valueOf(), MAX_LOCKED_VALUE);
    }

    function tokensCount() external view returns (uint256) {
        return _tokens.length();
    }

    function token(uint256 index) external view returns (TokenInfo memory) {
        IERC20Ex tokenInterface = IERC20Ex(_tokens.at(index));
        return TokenInfo({
            contractAddress: address(tokenInterface),
            name: tokenInterface.name(),
            symbol: tokenInterface.symbol(),
            decimals: tokenInterface.decimals(),
            balance: tokenInterface.balanceOf(address(this))
        });
    }

    function addToken(address token_) external shareOwner {
        _tokens.add(token_);

        _tokenValues[token_] = TokenValueInfo({
            timestamp: block.timestamp,
            cumulativePrice: _getLastCumulativePrice(token_)
        });
    }

    function removeToken(address token_) external shareOwner {
        _tokens.remove(token_);
        delete _tokenValues[token_];
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
        for (uint256 index = 0; index < _tokens.length(); index++) {
            IERC20 tokenContract = IERC20(_tokens.at(index));
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