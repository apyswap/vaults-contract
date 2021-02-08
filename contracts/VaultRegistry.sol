// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./Vault.sol";
import "./interfaces/IVaultTokenRegistry.sol";

contract VaultRegistry is IVaultTokenRegistry {
    using SafeMathUpgradeable for uint256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    mapping(address => EnumerableSetUpgradeable.AddressSet) _accountVaults;
    mapping(address => mapping(address => uint256)) _vaultAccountShare;

    event Transfer(address indexed vault, address indexed from, address indexed to, uint256 value);
    event Approval(address indexed vault, address indexed owner, address indexed spender, uint256 value);

    function createVault() public {
        Vault vault = new Vault();
        _accountVaults[msg.sender].add(address(vault));
    }

    function vaultCount(address user) public view returns (uint256) {
        return _accountVaults[user].length();
    }

    function vault(address user, uint256 index) public view returns (address) {
        return _accountVaults[user].at(index);
    }

    function balanceOf(address vault_, address account) external override view returns (uint256) {
        return _vaultAccountShare[vault_][account];
    }

    function transfer(address vault_, address recipient, uint256 amount) external override returns (bool) {
        _transfer(vault_, msg.sender, recipient, amount);
        return true;
    }

    function allowance(address vault_, address owner, address spender) external override view returns (uint256) {

    }

    function approve(address vault_, address spender, uint256 amount) external override returns (bool) {

    }

    function transferFrom(address vault_, address sender, address recipient, uint256 amount) external override returns (bool) {

    }

    function _transfer(address vault_, address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _vaultAccountShare[vault_][sender] = _vaultAccountShare[vault_][sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _vaultAccountShare[vault_][recipient] = _vaultAccountShare[vault_][recipient].add(amount);

        _updateOwnership(vault_, sender);
        _updateOwnership(vault_, recipient);

        emit Transfer(vault_, sender, recipient, amount);
    }

    function _updateOwnership(address vault_, address account) internal {
        uint256 balance = _vaultAccountShare[vault_][account];
        if (balance > 0) {
            _accountVaults[account].add(vault_);
        } else if (balance == 0) {
            _accountVaults[account].remove(vault_);
        }
    }
}