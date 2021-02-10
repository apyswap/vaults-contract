const Token = artifacts.require('TestToken');

module.exports = function(deployer, network, accounts) {
    if (network !== 'mainnet') {
        deployer.deploy(Token, 'Test Token', 'TTT', 1000000000000000000000000, accounts[0]);
    }
};