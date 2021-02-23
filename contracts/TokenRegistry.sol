// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "./interfaces/ITokenRegistry.sol";

struct TokenValueInfo {
    uint256 timestamp;
    uint256 cumulativePrice;
}

interface IERC20Ex is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

contract TokenRegistry is ITokenRegistry, Ownable {
    using SafeMath for uint256;

    address constant USDT_ = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant WETH_ = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function USDT() external override pure returns (address) { return USDT_; }
    function WETH() external override pure returns (address) { return WETH_; }

    IUniswapV2Factory private _uniswapFactory;
    
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private _tokens;
    EnumerableSet.AddressSet private _stables;
    mapping( address => TokenValueInfo ) private _tokenValues;

    constructor(IUniswapV2Factory uniswapFactory) public {
        _uniswapFactory = uniswapFactory;
        _addToken(WETH_, false);
    }

    function tokensCount() external override view returns (uint256) {
        return _tokens.length() + _stables.length();
    }

    function tokenAddress(uint256 index) external override view returns (address) {
        return _tokenAddress(index);
    }

    function _tokenAddress(uint256 index) internal view returns (address) {
        if (index < _tokens.length()) {
            return _tokens.at(index);
        } else {
            return _stables.at(index - _tokens.length());
        }
    }

    function token(uint256 index) external view returns (TokenInfo memory) {
        IERC20Ex tokenInterface = IERC20Ex(_tokenAddress(index));
        
        return TokenInfo({
            contractAddress: address(tokenInterface),
            name: tokenInterface.name(),
            symbol: tokenInterface.symbol(),
            decimals: tokenInterface.decimals()
        });
    }

    function addToken(address token_, bool isStable) external onlyOwner {
        _addToken(token_, isStable);
    }

    function _addToken(address token_, bool isStable) internal {
        if (isStable) {
            _stables.add(token_);
        } else {
            _tokens.add(token_);
            _tokenValues[token_] = TokenValueInfo({
                timestamp: block.timestamp,
                cumulativePrice: _getLastCumulativePrice(token_)
            });
        }
    }

    function removeToken(address token_) external onlyOwner {
        if (_tokens.contains(token_)) {
            _tokens.remove(token_);
        } else if (_stables.contains(token_)) {
            _stables.remove(token_);
        }
    }

    function tokenValue(address token_, uint256 balance) external override view returns (uint256) {
        if (balance == 0) {
            return 0;
        }
        if (_stables.contains(token_)) {
            return balance;
        }

        TokenValueInfo storage pastInfo = _tokenValues[token_];
        if (pastInfo.cumulativePrice == 0) {
            return 0;
        }

        uint256 cumulativePrice = _getLastCumulativePrice(token_);
        if (cumulativePrice == 0 || cumulativePrice <= pastInfo.cumulativePrice) {
            return 0;
        }
        if (block.timestamp <= pastInfo.timestamp) {
            return 0;
        }

        return cumulativePrice.sub(pastInfo.cumulativePrice).mul(balance).div(block.timestamp.sub(pastInfo.timestamp));
    }

    function _getLastCumulativePrice(address token_) internal view returns (uint256) {
        address pairAddress = _uniswapFactory.getPair(token_, USDT_);
        if (pairAddress == address(0)) {
            // Pair does not exist
            return 0;
        }
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        if (pair.token0() == token_) {
            return pair.price0CumulativeLast();
        }
        if (pair.token1() == token_) {
            return pair.price1CumulativeLast();
        }
        // Something went wrong, return 0
        return 0;
    }
}