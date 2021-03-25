const TokenRegistry = artifacts.require("TokenRegistry");
const UniswapValueOracle = artifacts.require("UniswapValueOracle");
const truffle_contract = require('@truffle/contract');
const UniswapV2Factory = truffle_contract(require('@uniswap/v2-core/build/UniswapV2Factory.json'));
const UniswapV2Pair = truffle_contract(require('@uniswap/v2-core/build/UniswapV2Pair.json'));
const USDT = artifacts.require("USDT");
const WETH = artifacts.require("WETH");
const RewardToken = artifacts.require("RewardToken");
const { time } = require('@openzeppelin/test-helpers');

contract("TokenRegistry", async accounts => {

    let uniswapV2Factory;
    let valueOracle;
    let tokenRegistry;
    let tokenUSDT;
    let tokenWETH;

    beforeEach(async () => {

        UniswapV2Factory.setProvider(web3._provider);
        UniswapV2Pair.setProvider(web3._provider);

        uniswapV2Factory = await UniswapV2Factory.new(accounts[0], {from: accounts[0]});
        tokenUSDT = await USDT.new();
        tokenWETH = await WETH.new();
        tokenRewar = await RewardToken.new();

        // Create test pairs
        await uniswapV2Factory.createPair(tokenUSDT.address, tokenWETH.address, {from: accounts[0]});

        let pairAddress = await uniswapV2Factory.getPair(tokenUSDT.address, tokenWETH.address);
        pair = await UniswapV2Pair.at(pairAddress);
        await pair.sync({from: accounts[0]});

        await tokenUSDT.transfer(pairAddress, web3.utils.toWei("2000"));
        await tokenWETH.transfer(pairAddress, web3.utils.toWei("1"));
        await pair.mint(accounts[0], {from: accounts[0]});
        await time.increase(5);
        await pair.sync({from: accounts[0]});

        valueOracle = await UniswapValueOracle.new(uniswapV2Factory.address, tokenUSDT.address);

        tokenRegistry = await TokenRegistry.new(valueOracle.address, tokenUSDT.address, tokenWETH.address, tokenRewar.address);

        await time.increase(5);
        await pair.sync({from: accounts[0]});
    });

    it("success: initialization", async () => {
        assert.equal(await tokenRegistry.tokenCount.call(), 3);
    });

    it("success: token info", async () => {
        const result = await tokenRegistry.token.call(0);
        assert.equal(result[0], tokenWETH.address);
        assert.equal(result[1], "Wrapped Ethereum");
        assert.equal(result[2], "WETH");
        assert.equal(result[3], "18");
    });

    it("success: token value", async () => {
        const ETH_BALANCE = web3.utils.toWei("100");
        const ETH_VALUE = web3.utils.toWei("200000");

        const result = await tokenRegistry.tokenValue.call(tokenWETH.address, ETH_BALANCE);
        assert.equal(result.toString(), ETH_VALUE);
    });
});
