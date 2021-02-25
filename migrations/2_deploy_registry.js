const VaultRegistry = artifacts.require("VaultRegistry");
const TokenRegistry = artifacts.require("TokenRegistry");
const contract = require('@truffle/contract');
const UniswapV2Factory = contract(require('@uniswap/v2-core/build/UniswapV2Factory.json'));
const USDT = artifacts.require('USDT');
const WETH = artifacts.require('WETH');

UniswapV2Factory.setProvider(this.web3._provider);

module.exports = async function (deployer, network, accounts) {
  let uniswapFactoryAddress;
  if (deployer.network == "ganache" || deployer.network == "development") {
    // Deploy Uniswap and create test pairs
    await deployer.deploy(UniswapV2Factory, accounts[0], {from: accounts[0]});
    uniswapFactoryAddress = (await UniswapV2Factory.deployed()).address;
    // TODO: Create test pairs
  } else {
    uniswapFactoryAddress = "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f";
  }
  let tokenUSDTAddress, tokenWETHAddress;
  if (deployer.network == "ganache" || deployer.network == "development") {
    await deployer.deploy(USDT);
    await deployer.deploy(WETH);
    tokenUSDTAddress = (await USDT.deployed()).address;
    tokenWETHAddress = (await WETH.deployed()).address;
  } else {
    tokenUSDTAddress = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
    tokenWETHAddress = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
  }
  await deployer.deploy(TokenRegistry, uniswapFactoryAddress, tokenUSDTAddress, tokenWETHAddress);
  await deployer.deploy(VaultRegistry, (await TokenRegistry.deployed()).address);
};
