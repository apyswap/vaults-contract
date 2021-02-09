// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./Vault.sol";
import "./interfaces/IVaultTokenRegistry.sol";

contract VaultRegistry is IVaultTokenRegistry {
    using SafeMathUpgradeable for uint256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    LockInfo[] private _lockInfo;

    mapping(address => EnumerableSetUpgradeable.AddressSet) private _accountVaults;
    mapping(address => mapping(address => uint256)) private _vaultAccountShare;
    mapping(address => mapping(address => mapping(address => uint256))) private _vaultAllowances;

    event Transfer(address indexed vault, address indexed from, address indexed to, uint256 value);
    event Approval(address indexed vault, address indexed owner, address indexed spender, uint256 value);

    constructor() public {
        _lockInfo.push(LockInfo({interval: 1 minutes, reward: 0}));
        _lockInfo.push(LockInfo({interval: 5 minutes, reward: 10}));
        _lockInfo.push(LockInfo({interval: 10 minutes, reward: 20}));
    }

    modifier fromVault(address vault_, address owner) {
        require(vault_ == msg.sender, "!vault");
        require(_accountVaults[owner].contains(vault_), "!owner");
        _;
    }

    function createVault() public {
        Vault vault = new Vault();
        _vaultAccountShare[address(vault)][msg.sender] = 1 ether;
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

    function transfer(address vault_, address sender, address recipient, uint256 amount) external fromVault(vault_, sender) override returns (bool) {
        _transfer(vault_, sender, recipient, amount);
        return true;
    }

    function allowance(address vault_, address owner, address spender) external override view returns (uint256) {
        return _vaultAllowances[vault_][owner][spender];
    }

    function approve(address vault_, address owner, address spender, uint256 amount) external fromVault(vault_, owner) override returns (bool) {
        _approve(vault_, owner, spender, amount);
        return true;
    }

    function transferFrom(address vault_, address spender, address sender, address recipient, uint256 amount) external fromVault(vault_, sender) override returns (bool) {
        _transfer(vault_, sender, recipient, amount);
        _approve(vault_, sender, spender, _vaultAllowances[vault_][sender][spender].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    // Calculates approximate USD value of ethereum and token balances
    function valueOf(uint256 ethBalance, address[] calldata tokens) external override view returns (uint256) {
        // TODO: Call etherscan router to get value of ethereum and tokens
        return 0;
    }

    function lockCount() external override view returns (uint256) {
        return _lockInfo.length;
    }

    function lockInfo(uint256 index) external override view returns (LockInfo memory) {
        return _lockInfo[index];
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

    function _approve(address vault_, address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _vaultAllowances[vault_][owner][spender] = amount;
        emit Approval(vault_, owner, spender, amount);
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