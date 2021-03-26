const BN = require("bn.js");

const TokenRegistry = artifacts.require("TokenRegistry");
const VaultRegistry = artifacts.require("VaultRegistry");
const WETH = artifacts.require("WETH");
const USDT = artifacts.require("USDT");
const Vault = artifacts.require("Vault");
const RewardToken = artifacts.require("RewardToken");
const toWei = web3.utils.toWei;

// Generic tests checking if all contracts are deployed correctly
contract("Deployment", async accounts => {

    let tokenRegistry;
    let vaultRegistry;
    let tokenWETH, tokenUSDT;
    let tokenReward;

    it("Success: deployment", async () => {
        tokenRegistry = await TokenRegistry.deployed();
        assert.exists(tokenRegistry);
        vaultRegistry = await VaultRegistry.deployed();
        assert.exists(vaultRegistry);
        tokenWETH = await WETH.deployed();
        assert.exists(tokenWETH);
        tokenUSDT = await USDT.deployed();
        assert.exists(tokenUSDT);
        tokenReward = await RewardToken.deployed();
        assert.exists(tokenReward);

        assert.equal(await vaultRegistry.tokenRegistry.call(), tokenRegistry.address);
        assert.equal(await vaultRegistry.tokenReward.call(), tokenReward.address);
        assert.equal(await tokenReward.balanceOf.call(vaultRegistry.address), toWei("100000"));

        // Check token registry tokens
        assert.equal(await tokenRegistry.tokenCount.call(), 3);
        assert.sameMembers([
            await tokenRegistry.tokenAddress.call(0),
            await tokenRegistry.tokenAddress.call(1),
            await tokenRegistry.tokenAddress.call(2),
        ], [
            WETH.address,
            RewardToken.address,
            USDT.address,
        ]);

        // Check Uniswap integration
        assert.equal((await tokenRegistry.tokenValue(USDT.address, "100")).toString(), "100");
        assert.equal((await tokenRegistry.tokenValue(WETH.address, "100")).toString(), "200000");
    });

    let vault;

    it("Success: create vault", async () => {
        let vaultRegistry = await VaultRegistry.deployed();
        await vaultRegistry.createVault();
        let vaultAddress = await vaultRegistry.vault.call(accounts[0], 0);
        vault = await Vault.at(vaultAddress);
        assert.exists(vault);
    });

    it("Success: transfer some value", async () => {
        await web3.eth.sendTransaction({from: accounts[0], to: vault.address, value: toWei("1")});
        tokenUSDT.transfer(vault.address, toWei("3"), { from: accounts[0] });
        tokenWETH.transfer(vault.address, toWei("2"), { from: accounts[0] });
        assert.equal((await vault.totalValue.call()).toString(), toWei("6003"));
    });

    it("Success: reward for locking", async () => {
        await vault.lock(2);
        let reward = new BN(toWei("1000")).divn(5); // 20% max reward = 1000
        assert.equal((await vault.rewardValue.call()).toString(), reward.toString());
        assert.equal((await vaultRegistry.rewardTotal()).toString(), toWei("100000"));
        assert.equal((await vaultRegistry.rewardAvailable()).toString(), new BN(toWei("100000")).sub(reward).toString());
    });
});
