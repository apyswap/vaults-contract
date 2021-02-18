// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "./Vault.sol";
import "./interfaces/IVaultTokenRegistry.sol";

struct TokenValueInfo {
    uint256 timestamp;
    uint256 cumulativePrice;
}

interface IERC20Ex is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

contract VaultRegistry is Ownable, IVaultTokenRegistry {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    address constant USDT_ = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant WETH_ = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function USDT() external override pure returns (address) { return USDT_; }
    function WETH() external override pure returns (address) { return WETH_; }

    LockInfo[] private _lockInfo;

    IUniswapV2Factory private _uniswapFactory;

    mapping(address => EnumerableSet.AddressSet) private _accountVaults;
    mapping(address => mapping(address => uint256)) private _vaultAccountShare;
    mapping(address => mapping(address => mapping(address => uint256))) private _vaultAllowances;

    EnumerableSet.AddressSet private _tokens;
    EnumerableSet.AddressSet private _stables;
    mapping( address => TokenValueInfo ) private _tokenValues;

    event Transfer(address indexed vault, address indexed from, address indexed to, uint256 value);
    event Approval(address indexed vault, address indexed owner, address indexed spender, uint256 value);

    constructor(IUniswapV2Factory uniswapFactory) public {
        //_uniswapFactory = uniswapFactory;

        //_lockInfo.push(LockInfo({interval: 1 minutes, reward: 0}));
        //_lockInfo.push(LockInfo({interval: 5 minutes, reward: 10}));
        //_lockInfo.push(LockInfo({interval: 10 minutes, reward: 20}));

        //_addToken(WETH_, false);
    }

    modifier fromVault(address vault_, address owner) {
        require(vault_ == msg.sender, "!vault");
        require(_accountVaults[owner].contains(vault_), "!owner");
        _;
    }

    function createVault() public {
        Vault vault = new Vault(this);
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

    function burn(AddressParams memory addresses, uint256 amount) external fromVault(addresses.vault, addresses.sender) override returns (bool) {
        _burn(addresses, amount);
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

    function _burn(AddressParams memory addresses, uint256 amount) internal virtual {
        require(addresses.sender != address(0), "ERC20: burn from the zero address");

        _vaultAccountShare[addresses.vault][addresses.sender] = _vaultAccountShare[addresses.vault][addresses.sender].sub(amount, "ERC20: burn amount exceeds balance");
        emit Transfer(addresses.vault, addresses.sender, address(0), amount);
    }

    function _updateOwnership(address vault_, address account) internal {
        uint256 balance = _vaultAccountShare[vault_][account];
        if (balance > 0) {
            _accountVaults[account].add(vault_);
        } else if (balance == 0) {
            _accountVaults[account].remove(vault_);
        }
    }

    function uniswapFactory() external override view returns (IUniswapV2Factory) {
        return _uniswapFactory;
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

    function token(uint256 index, address vault_) external view returns (TokenInfo memory) {
        IERC20Ex tokenInterface = IERC20Ex(_tokenAddress(index));
        
        return TokenInfo({
            contractAddress: address(tokenInterface),
            name: tokenInterface.name(),
            symbol: tokenInterface.symbol(),
            decimals: tokenInterface.decimals(),
            balance: tokenInterface.balanceOf(vault_)
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