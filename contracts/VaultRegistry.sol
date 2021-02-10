// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Vault.sol";
import "./interfaces/IVaultTokenRegistry.sol";

contract VaultRegistry is IVaultTokenRegistry {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    LockInfo[] private _lockInfo;

    mapping(address => EnumerableSet.AddressSet) private _accountVaults;
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

    function balanceOf(AddressParams memory addresses) external override view returns (uint256) {
        return _vaultAccountShare[addresses.vault][addresses.owner];
    }

    function transfer(AddressParams memory addresses, uint256 amount) external fromVault(addresses.vault, addresses.sender) override returns (bool) {
        _transfer(addresses, amount);
        return true;
    }

    function allowance(AddressParams memory addresses) external override view returns (uint256) {
        return _vaultAllowances[addresses.vault][addresses.owner][addresses.spender];
    }

    function approve(AddressParams memory addresses, uint256 amount) external fromVault(addresses.vault, addresses.owner) override returns (bool) {
        _approve(addresses, amount);
        return true;
    }

    function transferFrom(AddressParams memory addresses, uint256 amount) external fromVault(addresses.vault, addresses.sender) override returns (bool) {
        _transfer(addresses, amount);
        _approve(addresses, _vaultAllowances[addresses.vault][addresses.owner][addresses.spender].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function lockCount() external override view returns (uint256) {
        return _lockInfo.length;
    }

    function lockInfo(uint256 index) external override view returns (LockInfo memory) {
        return _lockInfo[index];
    }

    function _transfer(AddressParams memory addresses, uint256 amount) internal {
        require(addresses.sender != address(0), "ERC20: transfer from the zero address");
        require(addresses.recipient != address(0), "ERC20: transfer to the zero address");

        _vaultAccountShare[addresses.vault][addresses.sender] = 
            _vaultAccountShare[addresses.vault][addresses.sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _vaultAccountShare[addresses.vault][addresses.recipient] = 
            _vaultAccountShare[addresses.vault][addresses.recipient].add(amount);

        _updateOwnership(addresses.vault, addresses.sender);
        _updateOwnership(addresses.vault, addresses.recipient);

        emit Transfer(addresses.vault, addresses.sender, addresses.recipient, amount);
    }

    function _approve(AddressParams memory addresses, uint256 amount) internal {
        require(addresses.owner != address(0), "ERC20: approve from the zero address");
        require(addresses.spender != address(0), "ERC20: approve to the zero address");

        _vaultAllowances[addresses.vault][addresses.owner][addresses.spender] = amount;
        emit Approval(addresses.vault, addresses.owner, addresses.spender, amount);
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