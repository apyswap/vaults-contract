const TokenRegistry = artifacts.require("TokenRegistry");
const { pressAnyKey } = require('./_utils.js');


module.exports = async (callback) => {
  try {
    const len = process.argv.length;
    const tokenRegistryAddress = process.argv[len - 3];
    const tokenAddress = process.argv[len - 2];
    const isStable = process.argv[len - 1] === 'true';

    const tokenRegistry = await TokenRegistry.at(tokenRegistryAddress);

    console.log(`Add ${isStable ? '' : 'not '}stable token ${tokenAddress} to token registry ${tokenRegistryAddress}`)
    await pressAnyKey();

    await tokenRegistry.addToken(tokenAddress, isStable);
  } catch (e) {
    console.error(e);
  }
  callback();
}
