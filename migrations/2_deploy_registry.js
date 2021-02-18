const VaultRegistry = artifacts.require("VaultRegistry");
const TokenRegistry = artifacts.require("TokenRegistry");
const contract = require('@truffle/contract');
const UniswapV2Factory = contract(require('@uniswap/v2-core/build/UniswapV2Factory.json'));

UniswapV2Factory.setProvider(this.web3._provider);

module.exports = async function (deployer, network, accounts) {
  let uniswapFactoryAddress;
  console.log(deployer.network);
  if (deployer.network == "ganache" || deployer.network == "development") {
    // Deploy Uniswap and create test pairs
    await deployer.deploy(UniswapV2Factory, accounts[0], {from: accounts[0]});
    uniswapFactoryAddress = (await UniswapV2Factory.deployed()).address;
    // TODO: Create test pairs
  } else {
    uniswapFactoryAddress = "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f";
  }
  await deployer.deploy(TokenRegistry, uniswapFactoryAddress);
  await deployer.deploy(VaultRegistry, (await TokenRegistry.deployed()).address);
};
