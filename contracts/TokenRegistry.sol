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

    uint224 private constant Q112 = 2**112;

    address private _tokenUSDT;
    address private _tokenWETH;

    function USDT() external override view returns (address) { return _tokenUSDT; }
    function WETH() external override view returns (address) { return _tokenWETH; }

    IUniswapV2Factory private _uniswapFactory;
    
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private _tokens;
    EnumerableSet.AddressSet private _stables;
    mapping( address => TokenValueInfo ) private _tokenValues;

    constructor(IUniswapV2Factory uniswapFactory, address tokenUSDT, address tokenWETH) public {
        _uniswapFactory = uniswapFactory;
        _tokenUSDT = tokenUSDT;
        _tokenWETH = tokenWETH;
        _addToken(_tokenUSDT, true);
        _addToken(_tokenWETH, false);
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
            _tokenValues[token_] = _getTokenValueInfo(token_);
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

        TokenValueInfo memory valueInfo = _getTokenValueInfo(token_);
        if (valueInfo.cumulativePrice == 0 || valueInfo.cumulativePrice <= pastInfo.cumulativePrice) {
            return 0;
        }
        if (valueInfo.timestamp <= pastInfo.timestamp) {
            return 0;
        }

        return valueInfo.cumulativePrice.sub(pastInfo.cumulativePrice).mul(balance).div(Q112)
            .div(valueInfo.timestamp.sub(pastInfo.timestamp));
    }

    function _getTokenValueInfo(address token_) internal view returns (TokenValueInfo memory info) {
        address pairAddress = _uniswapFactory.getPair(token_, _tokenUSDT);
        if (pairAddress == address(0)) {
            // Pair does not exist
            return info;
        }
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        uint112 reserve0;
        uint112 reserve1;
        (reserve0, reserve1, info.timestamp) = pair.getReserves();
        if (reserve0 == 0 || reserve1 == 0) {
            return info;
        }
        if (pair.token0() == token_) {
            info.cumulativePrice = pair.price0CumulativeLast();
        }
        else if (pair.token1() == token_) {
            info.cumulativePrice = pair.price1CumulativeLast();
        } else {
            // Something went wrong, return 0
            return info;
        }
    }
}