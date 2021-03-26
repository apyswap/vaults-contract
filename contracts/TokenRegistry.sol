// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ITokenRegistry.sol";
import "./interfaces/IValueOracle.sol";

interface IERC20Ex is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

contract TokenRegistry is ITokenRegistry, Ownable {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    address private _tokenUSDT;
    address private _tokenWETH;
    address private _tokenReward;

    function USDT() external override view returns (address) { return _tokenUSDT; }
    function WETH() external override view returns (address) { return _tokenWETH; }

    IValueOracle private _valueOracle;

    EnumerableSet.AddressSet private _tokens;
    EnumerableSet.AddressSet private _stables;

    constructor(IValueOracle valueOracle, address tokenUSDT, address tokenWETH) public {
        _valueOracle = valueOracle;
        _tokenUSDT = tokenUSDT;
        _tokenWETH = tokenWETH;
        _addToken(_tokenUSDT, true);
        _addToken(_tokenWETH, false);
    }

    function tokenCount() external override view returns (uint256) {
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
            _valueOracle.updateValue(token_);
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

        return _valueOracle.tokenValue(token_, balance);
    }

    function valueToTokens(address token_, uint256 value) external override view returns (uint256) {
        if (value == 0) {
            return 0;
        }
        if (_stables.contains(token_)) {
            return value;
        }

        return _valueOracle.valueToTokens(token_, value);
    }
}
