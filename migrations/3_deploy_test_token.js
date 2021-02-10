const Token = artifacts.require('TestToken');

module.exports = function(deployer, network, accounts) {
    if (network !== 'mainnet') {
        deployer.deploy(Token);
    }
};