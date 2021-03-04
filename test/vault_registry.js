const VaultRegistry = artifacts.require("VaultRegistry");
const TokenRegistry = artifacts.require("TokenRegistry");
const truffle_contract = require('@truffle/contract');
const UniswapV2Factory = truffle_contract(require('@uniswap/v2-core/build/UniswapV2Factory.json'));
const USDT = artifacts.require("USDT");
const WETH = artifacts.require("WETH");

contract("VaultRegistry", async accounts => {

    let uniswapV2Factory;
    let tokenRegistry;
    let vaultRegistry;
    let tokenUSDT;
    let tokenWETH;

    beforeEach(async () => {

        UniswapV2Factory.setProvider(web3._provider);

        uniswapV2Factory = await UniswapV2Factory.new(accounts[0], {from: accounts[0]});

        tokenUSDT = await USDT.new();
        tokenWETH = await WETH.new();

        tokenRegistry = await TokenRegistry.new(uniswapV2Factory.address, tokenUSDT.address, tokenWETH.address);

        vaultRegistry = await VaultRegistry.new(tokenRegistry.address);
    });

    it("success: initialization", async () => {
        assert.equal(await vaultRegistry.vaultCount.call(accounts[0]), 0);
    });

    it("success: create vault", async () => {
        await vaultRegistry.createVault();
        assert.equal(await vaultRegistry.vaultCount.call(accounts[0]), 1);
    });
});