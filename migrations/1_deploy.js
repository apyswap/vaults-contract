const Vault = artifacts.require("Vault");
const VaultRegistry = artifacts.require("VaultRegistry");
const TokenRegistry = artifacts.require("TokenRegistry");
const SimpleValueOracle = artifacts.require("SimpleValueOracle");
const UniswapValueOracle = artifacts.require("UniswapValueOracle");
const contract = require('@truffle/contract');
const UniswapV2Factory = contract(require('@uniswap/v2-core/build/UniswapV2Factory.json'));
const UniswapV2Pair = contract(require('@uniswap/v2-core/build/UniswapV2Pair.json'));
const USDT = artifacts.require('USDT');
const WETH = artifacts.require('WETH');
const RewardToken = artifacts.require('RewardToken');
const BN = require('bn.js');

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

  const useSimpleValueOracle = (deployer.network.startsWith("goerli"));
  const localTestnet = (deployer.network == "ganache" || deployer.network == "development");
  const mainnet = (deployer.network == "mainnet");

  // Set up main currencies/tokens
  let tokenUSDTAddress, tokenWETHAddress, tokenRewardAddress;
  if (!mainnet) {
    await deployer.deploy(USDT);
    await deployer.deploy(WETH);
    await deployer.deploy(RewardToken);
    tokenUSDTAddress = (await USDT.deployed()).address;
    tokenWETHAddress = (await WETH.deployed()).address;
    tokenRewardAddress = (await RewardToken.deployed()).address;
  } else {
    tokenUSDTAddress = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
    tokenWETHAddress = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
    tokenRewardAddress = "" //TODO ;
  }

  let valueOracleAddress;
  if (useSimpleValueOracle) {

    // Use Simple oracle
    await deployer.deploy(SimpleValueOracle);
    const simpleOracle = await SimpleValueOracle.deployed();
    await simpleOracle.setValue(tokenWETHAddress, new BN("1800").mul(await simpleOracle.Q112.call()));
    valueOracleAddress = simpleOracle.address;
  } else {

    // Use Uniswap oracle
    let uniswapFactoryAddress;
    if (localTestnet) {
      // Deploy Uniswap and create test pairs
      await deployer.deploy(UniswapV2Factory, accounts[0], {from: accounts[0]});
      uniswapFactoryAddress = (await UniswapV2Factory.deployed()).address;

      // Create test pairs
      let factory = await UniswapV2Factory.deployed();
      await factory.createPair(tokenUSDTAddress, tokenWETHAddress, {from: accounts[0]});
      await factory.createPair(tokenUSDTAddress, tokenRewardAddress, {from: accounts[0]});

      let pairAddress = await factory.getPair(tokenUSDTAddress, tokenWETHAddress);
      let pairAddressReward = await factory.getPair(tokenUSDTAddress, tokenRewardAddress);
      const pair = await UniswapV2Pair.at(pairAddress);

      const pairReward = await UniswapV2Pair.at(pairAddressReward);
      await pair.sync({from: accounts[0]});
      await pairReward.sync({from: accounts[0]});

      let tokenUSDT = await USDT.at(tokenUSDTAddress);
      let tokenWETH = await WETH.at(tokenWETHAddress);
      let tokenReward = await RewardToken.at(tokenRewardAddress);

      await tokenUSDT.transfer(pairAddress, web3.utils.toWei("2000"));
      await tokenWETH.transfer(pairAddress, web3.utils.toWei("1"));

      await tokenUSDT.transfer(pairAddressReward, web3.utils.toWei("2000"));
      await tokenReward.transfer(pairAddressReward, web3.utils.toWei("1000"));

      await time.increase(5);
      await pair.mint(accounts[0], {from: accounts[0]});
      await pairReward.mint(accounts[0], {from: accounts[0]});
      await time.increase(5);
      await pair.sync({from: accounts[0]});
      await pairReward.sync({from: accounts[0]});

      await time.increase(5);
    } else {
      uniswapFactoryAddress = "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f";
    }

    await deployer.deploy(UniswapValueOracle, uniswapFactoryAddress, tokenUSDTAddress);
    valueOracleAddress = (await UniswapValueOracle.deployed()).address;

  }

  await deployer.deploy(TokenRegistry, valueOracleAddress, tokenUSDTAddress, tokenWETHAddress, tokenRewardAddress);
  await deployer.deploy(Vault);
  const tokenRegistry = await TokenRegistry.deployed();
  const vault = await Vault.deployed();
  await deployer.deploy(VaultRegistry, tokenRegistry.address, vault.address, 0, "" + Number.MAX_SAFE_INTEGER);
  const vaultRegistry = await VaultRegistry.deployed();

  if (!mainnet) {  // Add test lock intervals
    await vaultRegistry.addLock(1 * 60, 0);
    await vaultRegistry.addLock(5 * 60, 10);
    await vaultRegistry.addLock(10 * 60, 20);
  }

  // Sync pair price (for Uniswap oracle)
  if (!useSimpleValueOracle) {
    if (localTestnet) {
      await time.increase(5);
      let factory = await UniswapV2Factory.deployed();
      let pairAddress = await factory.getPair(tokenUSDTAddress, tokenWETHAddress);
      const pair = await UniswapV2Pair.at(pairAddress);
      await pair.sync({from: accounts[0]});
    }
  }

  // Configure reward tokens
  if (!mainnet) {
    let tokenReward = await RewardToken.deployed();
    let amount = web3.utils.toWei("100000");
    let vaultRegistry = await VaultRegistry.deployed();
    await tokenReward.transfer(vaultRegistry.address, amount);
    await vaultRegistry.setRewardValue(amount);
  }
  await vaultRegistry.setReward(tokenRewardAddress);
};