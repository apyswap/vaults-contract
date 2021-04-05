const VaultRegistry = artifacts.require("VaultRegistry");
const TokenRegistry = artifacts.require("TokenRegistry");
const Vault = artifacts.require("Vault");
const UniswapValueOracle = artifacts.require("UniswapValueOracle");
const truffle_contract = require("@truffle/contract");
const UniswapV2Factory = truffle_contract(require("@uniswap/v2-core/build/UniswapV2Factory.json"));
const USDT = artifacts.require("USDT");
const WETH = artifacts.require("WETH");
const RewardToken = artifacts.require("RewardToken");
const { Helper } = require("./_helper.js");
const toWei = web3.utils.toWei;

contract("VaultRegistry", async accounts => {

    let uniswapV2Factory;
    let valueOracle;
    let tokenRegistry;
    let vaultRegistry;
    let tokenUSDT;
    let tokenWETH;
    let tokenReward;

    beforeEach(async () => {

        UniswapV2Factory.setProvider(web3._provider);

        uniswapV2Factory = await UniswapV2Factory.new(accounts[0], {from: accounts[0]});

        tokenUSDT = await USDT.new();
        tokenWETH = await WETH.new();
        tokenReward = await RewardToken.new();

        valueOracle = await UniswapValueOracle.new(uniswapV2Factory.address, tokenUSDT.address);

        tokenRegistry = await TokenRegistry.new(valueOracle.address, tokenUSDT.address, tokenWETH.address);
        await tokenRegistry.addToken(tokenReward.address, false);

        let vault = await Vault.new();
        vaultRegistry = await VaultRegistry.new(tokenRegistry.address, vault.address, 0, "" + Number.MAX_SAFE_INTEGER);
        await vaultRegistry.addLock(1 * 60, 0);
        await vaultRegistry.addLock(5 * 60, 10);
        await vaultRegistry.addLock(10 * 60, 20);
    });

    it("Success: initialization", async () => {
        assert.equal(await vaultRegistry.vaultCount.call(accounts[0]), 0);
    });

    it("Success: create vault", async () => {
        const tx = await vaultRegistry.createVault();
        assert.equal(await vaultRegistry.vaultCount.call(accounts[0]), 1);
        const vaultAddress = await vaultRegistry.vault(accounts[0], 0);
        Helper.assertVaultCreatedEvent(tx, vaultAddress);
        assert.isDefined(vaultAddress);
        const vault = await Vault.at(vaultAddress);
        assert.equal((await vault.balanceOf(accounts[0])).toString(), toWei("1"))
    });

    it("Success: add lock", async () => {
        const lockCountBefore = await vaultRegistry.lockCount();
        await vaultRegistry.addLock("120", "5");
        const lockCountAfter = await vaultRegistry.lockCount();
        assert.equal(+lockCountBefore + 1, +lockCountAfter);
        const lockInfo = await vaultRegistry.lockInfo((+lockCountAfter - 1).toString());
        assert.equal(lockInfo.interval, "120");
        assert.equal(lockInfo.reward, "5");
    });

    it("Fail: add lock not owner", async () => {
        await Helper.tryCatch(vaultRegistry.addLock("120", "5", {from: accounts[1]}), "Ownable: caller is not the owner");
    });

    it("Success: update lock", async () => {
        const lockCountBefore = await vaultRegistry.lockCount();
        await vaultRegistry.updateLock((+lockCountBefore - 1).toString(), "360", "7");
        const lockCountAfter = await vaultRegistry.lockCount();
        assert.equal(+lockCountBefore, +lockCountAfter);
        const lockInfo = await vaultRegistry.lockInfo((+lockCountAfter - 1).toString());
        assert.equal(lockInfo.interval, "360");
        assert.equal(lockInfo.reward, "7");
    });

    it("Fail: update lock not owner", async () => {
        await Helper.tryCatch(vaultRegistry.updateLock("0", "120", "5", {from: accounts[1]}), "Ownable: caller is not the owner");
    });

    it("Success: delete lock", async () => {
        const lockCountBefore = await vaultRegistry.lockCount();
        await vaultRegistry.deleteLock("0");
        const lockCountAfter = await vaultRegistry.lockCount();
        assert.equal(+lockCountBefore - 1, +lockCountAfter);
    });

    it("Fail: delete lock not owner", async () => {
        await Helper.tryCatch(vaultRegistry.deleteLock("0", {from: accounts[1]}), "Ownable: caller is not the owner");
    });

    it("Success: setReward", async () => {
        await vaultRegistry.setReward(tokenWETH.address);
        const result = await vaultRegistry.tokenReward();
        assert.equal(tokenWETH.address, result);
    })

    it("Fail: setReward not owner", async () => {
        await Helper.tryCatch(vaultRegistry.setReward(tokenWETH.address, {from: accounts[1]}), "Ownable: caller is not the owner");
    })

    it("Success: setRewardValue", async () => {
        await vaultRegistry.setRewardValue( toWei("100000"));
        assert.equal((await vaultRegistry.rewardTotal()).toString(),  toWei("100000"));
        assert.equal((await vaultRegistry.rewardAvailable()).toString(), toWei("100000"));
        await vaultRegistry.createVault({from: accounts[1]});
        const vaultAddress = await vaultRegistry.vault(accounts[1], 0);
        const vault = await Vault.at(vaultAddress);
        tokenUSDT.transfer(vault.address, toWei("1000"));
        await vault.lock(1, {from: accounts[1]});
        assert.equal((await vaultRegistry.rewardTotal()).toString(), toWei("100000"));
        assert.equal((await vaultRegistry.rewardAvailable()).toString(), toWei("99900"));
        await vaultRegistry.setRewardValue(toWei("150000"));
        assert.equal((await vaultRegistry.rewardTotal()).toString(), toWei("150000"));
        assert.equal((await vaultRegistry.rewardAvailable()).toString(), toWei("149900"));
        await vaultRegistry.setRewardValue(toWei("50000"));
        assert.equal((await vaultRegistry.rewardTotal()).toString(), toWei("50000"));
        assert.equal((await vaultRegistry.rewardAvailable()).toString(), toWei("49900"));
        await Helper.tryCatch(vaultRegistry.setRewardValue(toWei("50")), "Negative reward");
    });

    it("Fail: setRewardValue not owner", async () => {
        await Helper.tryCatch(vaultRegistry.setRewardValue(toWei("500000"), {from: accounts[1]}), "Ownable: caller is not the owner");
    })

    it("Success: globalVaultCount and globalVault", async () => {
        await vaultRegistry.setRewardValue( toWei("100000"));
        await vaultRegistry.createVault({from: accounts[1]});
        const vaultAddress = await vaultRegistry.vault(accounts[1], 0);
        const globalVaultCount = await vaultRegistry.globalVaultCount();
        assert.equal(globalVaultCount, 1);
        const globalVault = await vaultRegistry.globalVault(0);
        assert.equal(globalVault, vaultAddress);
    });

    it("Success: update maxLockedValue", async () => {
        await vaultRegistry.setRewardValue( toWei("100000"));
        assert.equal((await vaultRegistry.maxLockedValue()).toString(), toWei("1000"));
        await vaultRegistry.setMaxLockedValue(toWei("100"));
        assert.equal((await vaultRegistry.maxLockedValue()).toString(), toWei("100"));
        await vaultRegistry.createVault({from: accounts[1]});
        const vaultAddress = await vaultRegistry.vault(accounts[1], 0);
        const vault = await Vault.at(vaultAddress);
        tokenUSDT.transfer(vault.address, toWei("1000"));
        await vault.lock(1, {from: accounts[1]});
        expect((await vault.rewardValue()).toString(), toWei("10"))
    });

    it("Fail: update maxLockedValue not owner", async () => {
        await Helper.tryCatch(vaultRegistry.setMaxLockedValue(toWei("1000"), {from: accounts[1]}), "Ownable: caller is not the owner");
    })
});
