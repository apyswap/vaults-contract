const BN = require('bn.js');

const TokenRegistry = artifacts.require("TokenRegistry");
const VaultRegistry = artifacts.require("VaultRegistry");
const WETH = artifacts.require("WETH");
const USDT = artifacts.require("USDT");
const Vault = artifacts.require("Vault");
const RewardToken = artifacts.require("RewardToken");

// Generic tests checking if all contracts are deployed correctly
contract("Deployment", async accounts => {

    let tokenRegistry;
    let vaultRegistry;
    let tokenWETH, tokenUSDT;
    let tokenReward;

    it("success: deployment", async () => {
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
        assert.equal(await tokenReward.balanceOf.call(vaultRegistry.address), web3.utils.toWei("100000"));

        // Check token registry tokens
        assert.equal(await tokenRegistry.tokenCount.call(), 2);
        assert.sameMembers([
            await tokenRegistry.tokenAddress.call(0),
            await tokenRegistry.tokenAddress.call(1),
        ], [
            WETH.address,
            USDT.address,
        ]);

        // Check Uniswap integration
        assert.equal((await tokenRegistry.tokenValue(USDT.address, "100")).toString(), "100"); 
        assert.equal((await tokenRegistry.tokenValue(WETH.address, "100")).toString(), "200000"); 
    });

    let vault;

    it("success: create vault", async () => {
        let vaultRegistry = await VaultRegistry.deployed();
        await vaultRegistry.createVault();
        let vaultAddress = await vaultRegistry.vault.call(accounts[0], 0);
        vault = await Vault.at(vaultAddress);
        assert.exists(vault);
    });

    it("success: transfer some value", async () => {
        await web3.eth.sendTransaction({from: accounts[0], to: vault.address, value: web3.utils.toWei("1")});
        tokenUSDT.transfer(vault.address, web3.utils.toWei("3"), { from: accounts[0] });
        tokenWETH.transfer(vault.address, web3.utils.toWei("2"), { from: accounts[0] });
        assert.equal((await vault.totalValue.call()).toString(), web3.utils.toWei("6003"));
    });

    it("success: reward for locking", async () => {
        await vault.lock(2);
        let reward = new BN(web3.utils.toWei("6003")).divn(5); // 20%
        assert.equal((await tokenReward.balanceOf.call(vault.address)).toString(), reward);
    });
});