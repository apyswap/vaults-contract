// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "./interfaces/IVaultTokenRegistry.sol";

contract Vault is IERC20Upgradeable, Initializable {

    IVaultTokenRegistry _tokenRegistry;
    uint256 public lockedUntil;

    constructor() public {
        lockedUntil = 0;
    }

    function initialize(IVaultTokenRegistry tokenRegistry) external initializer {
        _tokenRegistry = tokenRegistry;
    }

    function totalSupply() external override view returns (uint256) {
        return 1 ether;
    }

    function balanceOf(address account) external override view returns (uint256) {
        return _tokenRegistry.balanceOf(address(this), account);
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return _tokenRegistry.transfer(address(this), recipient, amount);
    }

    function isLocked() public view returns (bool) {
        return lockedUntil > block.timestamp;
    }
}