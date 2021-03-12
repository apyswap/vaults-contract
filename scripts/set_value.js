const Token = artifacts.require("USDT");
const SimpleValueOracle = artifacts.require("SimpleValueOracle");
const BN = require('bn.js');
const { pressAnyKey } = require('./_utils.js');

const MULTIPLICATOR = 1000000;

const getValue = async (valueOracle, tokenAddress) => {
    let value = await valueOracle.getCurrentValue.call(tokenAddress, MULTIPLICATOR);
    return value.toNumber() / MULTIPLICATOR;
}

module.exports = async (callback) => {
    const len = process.argv.length;
    const oracleAddress = process.argv[len - 3];
    const tokenAddress = process.argv[len - 2];
    let value = process.argv[len - 1];
    console.log(`SimpleValueOracle at ${oracleAddress}`);
    console.log(`Set token ${tokenAddress} value to $${value}`); 
    await pressAnyKey();
    
    console.log(`Reading current value...`);
    // Read token details
    const token = await Token.at(tokenAddress);
    console.log(`Token is ${await token.symbol.call()}`);

    const valueOracle = await SimpleValueOracle.at(oracleAddress)
    console.log(`Current value is ${await getValue(valueOracle, tokenAddress)}`);

    await pressAnyKey();

    try {
        console.log(`Setting new value...`);
        value = Math.floor(parseFloat(value) * MULTIPLICATOR);
        const Q112 = await valueOracle.Q112.call();
        console.log(Q112.toString());
        value = Q112.mul(new BN(value)).divn(MULTIPLICATOR);
        console.log(value.toString());
        await valueOracle.setValue(tokenAddress, value);

        console.log(`New value is ${await getValue(valueOracle, tokenAddress)}`);
    } catch(error) {
        console.log(error)
    }

    callback();
}