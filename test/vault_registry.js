const VaultRegistry = artifacts.require("VaultRegistry");
const TokenRegistry = artifacts.require("TokenRegistry");
const Vault = artifacts.require("Vault");
const UniswapValueOracle = artifacts.require("UniswapValueOracle");
const truffle_contract = require('@truffle/contract');
const UniswapV2Factory = truffle_contract(require('@uniswap/v2-core/build/UniswapV2Factory.json'));
const USDT = artifacts.require("USDT");
const WETH = artifacts.require("WETH");
const RewardToken = artifacts.require("RewardToken");

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

        tokenRegistry = await TokenRegistry.new(valueOracle.address, tokenUSDT.address, tokenWETH.address, tokenReward.address);

        let vault = await Vault.new();
        vaultRegistry = await VaultRegistry.new(tokenRegistry.address, vault.address, 0, "" + Number.MAX_SAFE_INTEGER);
    });

    it("success: initialization", async () => {
        assert.equal(await vaultRegistry.vaultCount.call(accounts[0]), 0);
    });

    it("success: create vault", async () => {
        await vaultRegistry.createVault();
        assert.equal(await vaultRegistry.vaultCount.call(accounts[0]), 1);
        const vaultAddress = await vaultRegistry.vault(accounts[0], 0);
        assert.isDefined(vaultAddress);
        const vault = await Vault.at(vaultAddress);
        assert.equal((await vault.balanceOf(accounts[0])).toString(), web3.utils.toWei("1"))
    });
});
