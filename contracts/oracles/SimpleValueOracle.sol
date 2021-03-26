// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "../interfaces/IValueOracle.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

contract SimpleValueOracle is IValueOracle, Ownable {
    using SafeMath for uint256;

    uint224 public constant Q112 = 2**112;

    mapping( address => uint256 ) private _tokenValues;

    function updateValue(address token) external override {}    // Do nothing

    function setValue(address token, uint256 value) external onlyOwner {
        _tokenValues[token] = value;
    }

    function tokenValue(address token, uint256 balance) external override view returns (uint256) {
        return _tokenValues[token].mul(balance).div(Q112);
    }

    function valueToTokens(address token, uint256 balance) external override view returns (uint256) {
        return balance.mul(Q112).div(_tokenValues[token]);
    }
}
