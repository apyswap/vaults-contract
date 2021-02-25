const TokenRegistry = artifacts.require("TokenRegistry");
const truffle_contract = require('@truffle/contract');
const UniswapV2Factory = truffle_contract(require('@uniswap/v2-core/build/UniswapV2Factory.json'));
const USDT = artifacts.require("USDT");
const WETH = artifacts.require("WETH");

contract("TokenRegistry", async accounts => {

    let uniswapV2Factory;
    let tokenRegistry;
    let tokenUSDT;
    let tokenWETH;

    beforeEach(async () => {

        UniswapV2Factory.setProvider(web3._provider);

        uniswapV2Factory = await UniswapV2Factory.new(accounts[0], {from: accounts[0]});
        tokenUSDT = await USDT.new();
        tokenWETH = await WETH.new();

        tokenRegistry = await TokenRegistry.new(uniswapV2Factory.address, tokenUSDT.address, tokenWETH.address);
    });

    it("success: initialization", async () => {
        assert.equal(await tokenRegistry.tokensCount.call(), 2);
    });

    it("success: token info", async () => {
        const result = await tokenRegistry.token.call(0);
        assert.equal(result[0], tokenWETH.address);
        assert.equal(result[1], "Wrapped Ethereum");
        assert.equal(result[2], "WETH");
        assert.equal(result[3], "18");
    });
});