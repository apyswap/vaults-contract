const VaultRegistry = artifacts.require("VaultRegistry");
const TokenRegistry = artifacts.require("TokenRegistry");
const UniswapValueOracle = artifacts.require("UniswapValueOracle");
const contract = require('@truffle/contract');
const UniswapV2Factory = contract(require('@uniswap/v2-core/build/UniswapV2Factory.json'));
const UniswapV2Pair = contract(require('@uniswap/v2-core/build/UniswapV2Pair.json'));
const USDT = artifacts.require('USDT');
const WETH = artifacts.require('WETH');
const RewardToken = artifacts.require('RewardToken');
require('@openzeppelin/test-helpers/configure')({
  provider: web3._provider,
  singletons: {
    abstraction: 'truffle',
  },
});
const { time } = require('@openzeppelin/test-helpers');    

UniswapV2Factory.setProvider(web3._provider);
UniswapV2Pair.setProvider(web3._provider);

module.exports = async function (deployer, network, accounts) {
  let uniswapFactoryAddress;
  if (deployer.network == "ganache" || deployer.network == "development") {
    // Deploy Uniswap and create test pairs
    await deployer.deploy(UniswapV2Factory, accounts[0], {from: accounts[0]});
    uniswapFactoryAddress = (await UniswapV2Factory.deployed()).address;
  } else {
    uniswapFactoryAddress = "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f";
  }
  let tokenUSDTAddress, tokenWETHAddress;
  let pair;
  if (deployer.network == "ganache" || deployer.network == "development") {
    await deployer.deploy(USDT);
    await deployer.deploy(WETH);
    let tokenUSDT = await USDT.deployed();
    let tokenWETH = await WETH.deployed();
    tokenUSDTAddress = tokenUSDT.address;
    tokenWETHAddress = tokenWETH.address;

    // Create test pairs
    let factory = await UniswapV2Factory.deployed();
    await factory.createPair(tokenUSDTAddress, tokenWETHAddress, {from: accounts[0]});
    
    let pairAddress = await factory.getPair(tokenUSDTAddress, tokenWETHAddress);
    pair = await UniswapV2Pair.at(pairAddress);
    await pair.sync({from: accounts[0]});

    await tokenUSDT.transfer(pairAddress, web3.utils.toWei("2000"));
    await tokenWETH.transfer(pairAddress, web3.utils.toWei("1"));
    await time.increase(5);
    await pair.mint(accounts[0], {from: accounts[0]});
    await time.increase(5);
    await pair.sync({from: accounts[0]});

    await time.increase(5);
    
  } else {
    tokenUSDTAddress = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
    tokenWETHAddress = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
  }

  await deployer.deploy(UniswapValueOracle, uniswapFactoryAddress, tokenUSDTAddress);
  await deployer.deploy(TokenRegistry, (await UniswapValueOracle.deployed()).address, 
    tokenUSDTAddress, tokenWETHAddress);
  await deployer.deploy(VaultRegistry, (await TokenRegistry.deployed()).address, 0, "" + Number.MAX_SAFE_INTEGER);

  if (deployer.network == "ganache" || deployer.network == "development") {
    await time.increase(5);
    await pair.sync({from: accounts[0]});
  }

  // Configure reward tokens
  
  if (deployer.network != "mainnet") {
    await deployer.deploy(RewardToken);
    let tokenReward = await RewardToken.deployed();

    let tokenRewardAddress = tokenReward.address;
    let vaultRegistry = await VaultRegistry.deployed();
    let amount = web3.utils.toWei("100000");
    await tokenReward.approve(vaultRegistry.address, amount);
    await vaultRegistry.setReward(tokenRewardAddress, amount);
  }
};
