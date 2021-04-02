const { Helper } = require("./_helper.js");
const VaultRegistry = artifacts.require("VaultRegistry");
const TokenRegistry = artifacts.require("TokenRegistry");
const Vault = artifacts.require("Vault");
const SimpleValueOracle = artifacts.require("SimpleValueOracle");
const truffle_contract = require("@truffle/contract");
const UniswapV2Factory = truffle_contract(require("@uniswap/v2-core/build/UniswapV2Factory.json"));
const { time } = require("@openzeppelin/test-helpers");
const USDT = artifacts.require("USDT");
const WETH = artifacts.require("WETH");
const RewardToken = artifacts.require("RewardToken");
const BN = web3.utils.BN;
const toWei = web3.utils.toWei;

contract("Vault", async accounts => {

  let uniswapV2Factory;
  let valueOracle;
  let tokenRegistry;
  let vaultRegistry;
  let tokenUSDT;
  let tokenWETH;
  let user1 = accounts[1];
  let user2 = accounts[2];
  let vault;
  let tokenReward;

  beforeEach(async () => {

    UniswapV2Factory.setProvider(web3._provider);

    uniswapV2Factory = await UniswapV2Factory.new(accounts[0], {from: accounts[0]});

    tokenUSDT = await USDT.new();
    tokenWETH = await WETH.new();
    tokenReward = await RewardToken.new();


    valueOracle = await SimpleValueOracle.new();
    await valueOracle.setValue(tokenUSDT.address, new BN("2").pow(new BN("112"))); // 1 USDT = $1
    await valueOracle.setValue(tokenWETH.address, new BN("2").pow(new BN("112")).mul(new BN("7"))); // 1 WETH = $7
    await valueOracle.setValue(tokenReward.address, new BN("2").pow(new BN("112")).div(new BN("2"))); // 1 APYS = $0.5

    tokenRegistry = await TokenRegistry.new(valueOracle.address, tokenUSDT.address, tokenWETH.address);
    await tokenRegistry.addToken(tokenReward.address, false);

    const vaultPrototype = await Vault.new();
    vaultRegistry = await VaultRegistry.new(tokenRegistry.address, vaultPrototype.address, 0, "" + Number.MAX_SAFE_INTEGER);

    await vaultRegistry.addLock(1 * 60, 0);
    await vaultRegistry.addLock(5 * 60, 10);
    await vaultRegistry.addLock(10 * 60, 20);

    await vaultRegistry.setReward(tokenReward.address);
    await vaultRegistry.setRewardValue(toWei("100000"));
    await tokenReward.transfer(vaultRegistry.address, toWei("100000"));

    await vaultRegistry.createVault({from: user1});
    const vaultAddressUser1 = await vaultRegistry.vault(user1, 0);
    vault = await Vault.at(vaultAddressUser1);
  });

  it("Success: withdraw", async () => {
    await vault.send(toWei("1")); // 1 ETH = $7
    await tokenUSDT.transfer(vault.address, toWei("16")); // 16 USDT = $16
    await tokenWETH.transfer(vault.address, toWei("5")); // 5 WETH = $35
    await tokenReward.transfer(vault.address, toWei("8")); // 8 APYS = $4

    assert.equal((await vault.totalValue()).toString(), toWei("62")); // (1 * 7) + 16 + (5 * 7) + (8 / 2) = 62

    // lock
    const tx = await vault.lock("1", {from: user1});
    Helper.assertLockedEvent(tx, {account: user1, interval: 5 * 60, lockedValue: toWei("62"), rewardValue: toWei("6.2")})
    const blocktime = await time.latest();
    assert.equal((await vault.lockedSince()).toString(), blocktime);
    assert.equal((await vault.lockedUntil()).toString(), (+blocktime + 5 * 60).toString());
    assert.equal((await vault.rewardValue()).toString(), toWei("6.2")); // 62 * 10% = 6.2
    assert.equal((await vaultRegistry.rewardAvailable()).toString(), toWei("99993.8")); // 10000 - 6.2 = 99993.8

    // transfer
    await vault.transfer(user2, toWei("0.4", "ether"), {from: user1});

    assert.equal((await vaultRegistry.vaultCount(user2)).toString(), "1");

    assert.equal((await vault.balanceOf(user1)).toString(), toWei("0.6"));
    assert.equal((await vault.balanceOf(user2)).toString(), toWei("0.4"));

    await time.increase(5 * 60 + 1);

    const user1EthBalanceBeforeWithdraw = await web3.eth.getBalance(user1);
    const user2EthBalanceBeforeWithdraw = await web3.eth.getBalance(user2);

    // withdraw user 2
    const withdraw2Tx = await vault.withdraw({from: user2});
    Helper.assertWithdrawnEvent(withdraw2Tx, user2, toWei("0.4"));
    const gasPrice = await web3.eth.getGasPrice();

    assert.equal((await vault.balanceOf(user2)).toString(), toWei("0"));
    assert.equal((await tokenReward.balanceOf(user2)).toString(), toWei("8.16")); // (6.2 * 0.4) * 2 + (8 * 0.4) = 7.68
    const user1EthBalanceAfterWithdraw2 = await web3.eth.getBalance(user1);
    const user2EthBalanceAfterWithdraw2 = await web3.eth.getBalance(user2);

    const fee2 = new BN(gasPrice).mul(new BN(withdraw2Tx.receipt.gasUsed));
    assert.equal(user1EthBalanceAfterWithdraw2, user1EthBalanceBeforeWithdraw);
    assert.equal(user2EthBalanceAfterWithdraw2, new BN(user2EthBalanceBeforeWithdraw).add(new BN(toWei("0.4"))).sub(fee2).toString());

    assert.equal((await tokenUSDT.balanceOf(user2)).toString(), toWei("6.4")); // 16 * 0.4 = 6.4
    assert.equal((await tokenWETH.balanceOf(user2)).toString(), toWei("2")); // 5 * 0.4 = 2

    // withdraw user 1
    const withdraw1Tx = await vault.withdraw({from: user1});
    Helper.assertWithdrawnEvent(withdraw1Tx, user1, toWei("0.6"));
    const fee1 = new BN(gasPrice).mul(new BN(withdraw1Tx.receipt.gasUsed));
    assert.equal((await vault.balanceOf(user1)), toWei("0"));
    assert.equal((await tokenReward.balanceOf(user1)), toWei("12.24")); // (6.2 * 0.6) * 2 + (8 * 0.6) = 11.52

    const user1EthBalanceAfterWithdraw1 = await web3.eth.getBalance(user1);
    const user2EthBalanceAfterWithdraw1 = await web3.eth.getBalance(user2);

    assert.equal(user1EthBalanceAfterWithdraw1, new BN(user1EthBalanceBeforeWithdraw).add(new BN(toWei("0.6"))).sub(fee1).toString());
    assert.equal(user2EthBalanceAfterWithdraw1, user2EthBalanceAfterWithdraw2);

    assert.equal((await tokenUSDT.balanceOf(user1)).toString(), toWei("9.6"));  // 16 * 0.6= 9.6
    assert.equal((await tokenWETH.balanceOf(user1)).toString(), toWei("3")); // 5 * 0.6 = 3
  });


  it("Fail: wrong time", async () => {
    const vaultRegistryActiveInTheFuture = await VaultRegistry.new(tokenRegistry.address, vault.address, Math.floor(Date.now() / 1000) + 86400, "" + Number.MAX_SAFE_INTEGER);
    const vaultRegistryActiveInThePast = await VaultRegistry.new(tokenRegistry.address, vault.address, 0, Math.floor(Date.now() / 1000) - 86400);
    await Helper.tryCatch(vaultRegistryActiveInTheFuture.createVault({from: user1}), "!active");
    await Helper.tryCatch(vaultRegistryActiveInThePast.createVault({from: user1}), "!active");
  });

  it("Fail: transfer before lock", async () => {
    await Helper.tryCatch(vault.transfer(user2, toWei("0.4", "ether"), {from: user1}), "!locked");
  });

  it("Fail: lock by another user", async () => {
    await Helper.tryCatch(vault.lock("1", {from: user2}), "!share owner");
  });

  it("Fail: already locked", async () => {
    await vault.lock("1", {from: user1});
    await Helper.tryCatch(vault.lock("1", {from: user1}), "!neverlocked");
  });

  it("Success: lock zero amount", async () => {
    await vault.lock("0", {from: user1});
    assert.equal((await vault.rewardValue()).toString(), toWei("0"));
    assert.equal((await vaultRegistry.rewardAvailable()).toString(), toWei("100000"));
    await time.increase(61);
    await vault.withdraw({from: user1});
  });

  it("Fail: withdraw while locked", async () => {
    await vault.send(toWei("0.01"));
    await vault.lock("0", {from: user1});
    await Helper.tryCatch(vault.withdraw({from: user1}), "locked");
  });

  it("Success: transfer all", async () => {
    await vault.send(toWei("1"));
    await vault.lock("0", {from: user1});
    await vault.transfer(user2, toWei("1", "ether"), {from: user1});
    assert.equal((await vaultRegistry.vaultCount(user1)).toString(), "0");
    assert.equal((await vaultRegistry.vaultCount(user2)).toString(), "1");
  });

  it("Success: max locked value", async () => {
    await tokenWETH.transfer(vault.address, toWei("150"));
    await vault.lock("1", {from: user1});
    assert.equal((await vault.rewardValue()).toString(), toWei("100"));
    assert.equal((await vaultRegistry.rewardAvailable()).toString(), toWei("99900"));
  });

  it("Success: unlock", async () => {
    await tokenWETH.transfer(vault.address, toWei("10"));
    await vault.lock("1", {from: user1});
    assert.equal((await vault.rewardValue()).toString(), toWei("7"));
    assert.equal((await vaultRegistry.rewardAvailable()).toString(), toWei("99993"));
    const tx = await vault.unlock({from: user1});
    Helper.assertUnlockedEvent(tx, user1);
    assert.equal((await vault.rewardValue()).toString(), toWei("0"));
    assert.equal((await vaultRegistry.rewardAvailable()).toString(), toWei("99993"));
    await vault.withdraw({from: user1});
    assert.equal((await tokenReward.balanceOf(user1)).toString(), toWei("0"));
  });

  it("Fail: unlock after transfer", async () => {
    await tokenWETH.transfer(vault.address, toWei("10"));
    await vault.lock("1", {from: user1});
    await vault.transfer(user2, toWei("0.4", "ether"), {from: user1});
    await Helper.tryCatch(vault.unlock({from: user1}), "!share owner");
  });

});
