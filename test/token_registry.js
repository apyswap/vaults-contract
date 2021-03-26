const TokenRegistry = artifacts.require("TokenRegistry");
const UniswapValueOracle = artifacts.require("UniswapValueOracle");
const truffle_contract = require("@truffle/contract");
const UniswapV2Factory = truffle_contract(require("@uniswap/v2-core/build/UniswapV2Factory.json"));
const UniswapV2Pair = truffle_contract(require("@uniswap/v2-core/build/UniswapV2Pair.json"));
const USDT = artifacts.require("USDT");
const WETH = artifacts.require("WETH");
const RewardToken = artifacts.require("RewardToken");
const { time } = require("@openzeppelin/test-helpers");
const toWei = web3.utils.toWei;

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
        tokenReward = await RewardToken.new();

        // Create test pairs
        await uniswapV2Factory.createPair(tokenUSDT.address, tokenWETH.address, {from: accounts[0]});

        let pairAddress = await uniswapV2Factory.getPair(tokenUSDT.address, tokenWETH.address);
        pair = await UniswapV2Pair.at(pairAddress);
        await pair.sync({from: accounts[0]});

        await tokenUSDT.transfer(pairAddress, toWei("2000"));
        await tokenWETH.transfer(pairAddress, toWei("1"));
        await pair.mint(accounts[0], {from: accounts[0]});
        await time.increase(5);
        await pair.sync({from: accounts[0]});

        valueOracle = await UniswapValueOracle.new(uniswapV2Factory.address, tokenUSDT.address);

        tokenRegistry = await TokenRegistry.new(valueOracle.address, tokenUSDT.address, tokenWETH.address);
        await tokenRegistry.addToken(tokenReward.address, false);

        await time.increase(5);
        await pair.sync({from: accounts[0]});
    });

    it("Success: initialization", async () => {
        assert.equal(await tokenRegistry.tokenCount(), 3);
    });

    it("Success: token info", async () => {
        const result = await tokenRegistry.token.call(0);
        assert.equal(result[0], tokenWETH.address);
        assert.equal(result[1], "Wrapped Ethereum");
        assert.equal(result[2], "WETH");
        assert.equal(result[3], "18");
    });

    it("Success: token value", async () => {
        const ETH_BALANCE = toWei("100");
        const ETH_VALUE = toWei("200000");

        const result = await tokenRegistry.tokenValue(tokenWETH.address, ETH_BALANCE);
        assert.equal(result.toString(), ETH_VALUE);
    });

    it("Success: value in token", async () => {
        const ETH_BALANCE = toWei("100");
        const VALUE_TO_ETH = toWei("0.05");

        const result = await tokenRegistry.valueToTokens(tokenWETH.address, ETH_BALANCE);
        assert.equal(result.toString(), VALUE_TO_ETH);
    });

    it("Success: removeToken", async () => {
        await tokenRegistry.removeToken(tokenReward.address);
        assert.equal((await tokenRegistry.tokenCount()).toString(), "2");
    });

    it("Success: removeToken not found", async () => {
        await tokenRegistry.removeToken(accounts[2]);
        assert.equal((await tokenRegistry.tokenCount()).toString(), "3");
    });
});
