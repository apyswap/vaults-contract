const SimpleValueOracle = artifacts.require("SimpleValueOracle");
const USDT = artifacts.require("USDT");
const WETH = artifacts.require("WETH");
const BN = require("bn.js");
const toWei = web3.utils.toWei;

contract("SimpleValueOracle", async accounts => {

    let valueOracle;
    let tokenUSDT;
    let tokenWETH;

    beforeEach(async () => {
        valueOracle = await SimpleValueOracle.new();
        tokenUSDT = await USDT.deployed();
        tokenWETH = await WETH.deployed();
    });

    it("Success: known token", async () => {
        let rateNumerator = new BN("1777356");
        let rateDenominator = new BN("1000");
        await valueOracle.setValue(tokenWETH.address, rateNumerator.mul(await valueOracle.Q112.call()).div(rateDenominator));

        let result = await valueOracle.tokenValue(tokenWETH.address, toWei("100"));
        result = result.addn(1);    // Fix rounding errors
        assert.equal(result.toString(), toWei("177735.6"));

        result = await valueOracle.valueToTokens(tokenWETH.address, toWei("100"));
        assert.equal(result.toString(), toWei("0.056263348479426743")); // (1000 * 100) / 1777356
    });

    it("Success: unknown token", async () => {
        let result = await valueOracle.tokenValue.call(tokenUSDT.address, toWei("123"));
        assert.equal(result.toString(), "0");
    });
});
