// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/presets/ERC20PresetFixedSupply.sol";

contract TestToken is ERC20PresetFixedSupply {
    constructor() public ERC20PresetFixedSupply("Test token", "TTT", 1000000 ether, msg.sender) {}
}

contract USDT is ERC20PresetFixedSupply {
    constructor() public ERC20PresetFixedSupply("Tether", "USDT", 1000000 ether, msg.sender) {}
}

contract WETH is ERC20PresetFixedSupply {
    constructor() public ERC20PresetFixedSupply("Wrapped Ethereum", "WETH", 1000000 ether, msg.sender) {}
}