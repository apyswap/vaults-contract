// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Vault.sol";
import "./interfaces/IVaultRegistry.sol";

contract VaultRegistry is Ownable, IVaultRegistry {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    LockInfo[] private _lockInfo;

    ITokenRegistry _tokenRegistry;

    mapping(address => EnumerableSet.AddressSet) private _accountVaults;
    
    constructor(ITokenRegistry tokenRegistry) public {

        _tokenRegistry = tokenRegistry;

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
        Vault vault = new Vault(msg.sender, this, _tokenRegistry);
        _accountVaults[msg.sender].add(address(vault));
    }

    function vaultCount(address user) public view returns (uint256) {
        return _accountVaults[user].length();
    }

    function vault(address user, uint256 index) public view returns (address) {
        return _accountVaults[user].at(index);
    }

    function lockCount() external override view returns (uint256) {
        return _lockInfo.length;
    }

    function lockInfo(uint256 index) external override view returns (LockInfo memory) {
        return _lockInfo[index];
    }

    function updateOwnership(IERC20 vault_, address sender, address recipient) external override {
        require(_accountVaults[sender].contains(address(vault_)), "!vault");
        if (vault_.balanceOf(sender) == 0) {
            _accountVaults[sender].remove(address(vault_));
        }
        if (vault_.balanceOf(recipient) > 0) {
            _accountVaults[recipient].add(address(vault_));
        }
    }
}