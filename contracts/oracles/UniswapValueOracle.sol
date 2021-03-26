// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "../interfaces/IValueOracle.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

struct TokenValueInfo {
    uint256 timestamp;
    uint256 cumulativePrice;
}

contract UniswapValueOracle is IValueOracle, Ownable {
    using SafeMath for uint256;

    uint224 private constant Q112 = 2**112;

    IUniswapV2Factory private _uniswapFactory;
    address private _tokenUSDT;

    mapping( address => TokenValueInfo ) private _tokenValues;

    constructor(IUniswapV2Factory uniswapFactory, address tokenUSDT) public {
        _uniswapFactory = uniswapFactory;
        _tokenUSDT = tokenUSDT;
    }

    function updateValue(address token) external override {
        _tokenValues[token] = _getTokenValueInfo(token);
    }

    function tokenValue(address token, uint256 balance) external override view returns (uint256) {
        TokenValueInfo storage pastInfo = _tokenValues[token];
        if (pastInfo.cumulativePrice == 0) {
            return 0;
        }

        TokenValueInfo memory valueInfo = _getTokenValueInfo(token);
        if (valueInfo.cumulativePrice == 0 || valueInfo.cumulativePrice <= pastInfo.cumulativePrice) {
            return 0;
        }
        if (valueInfo.timestamp <= pastInfo.timestamp) {
            return 0;
        }

        return valueInfo.cumulativePrice.sub(pastInfo.cumulativePrice).mul(balance).div(Q112)
            .div(valueInfo.timestamp.sub(pastInfo.timestamp));
    }

    function valueToTokens(address token, uint256 balance) external override view returns (uint256) {
        TokenValueInfo storage pastInfo = _tokenValues[token];
        if (pastInfo.cumulativePrice == 0) {
            return 0;
        }

        TokenValueInfo memory valueInfo = _getTokenValueInfo(token);
        if (valueInfo.cumulativePrice == 0 || valueInfo.cumulativePrice <= pastInfo.cumulativePrice) {
            return 0;
        }
        if (valueInfo.timestamp <= pastInfo.timestamp) {
            return 0;
        }

        return valueInfo.timestamp.sub(pastInfo.timestamp).mul(balance).mul(Q112)
            .div(valueInfo.cumulativePrice.sub(pastInfo.cumulativePrice));
    }

    function _getTokenValueInfo(address token) internal view returns (TokenValueInfo memory info) {
        address pairAddress = _uniswapFactory.getPair(token, _tokenUSDT);
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
        if (pair.token0() == token) {
            info.cumulativePrice = pair.price0CumulativeLast();
        }
        else if (pair.token1() == token) {
            info.cumulativePrice = pair.price1CumulativeLast();
        } else {
            // Something went wrong, return 0
            return info;
        }
    }
}
