const TokenRegistry = artifacts.require("TokenRegistry");


module.exports = async (callback) => {
  try {
    const len = process.argv.length;
    const tokenRegistryAddress = process.argv[len - 3];
    const tokenAddress = process.argv[len - 2];
    const isStable = process.argv[len - 1] === 'true';

    const tokenRegistry = await TokenRegistry.at(tokenRegistryAddress);
    await tokenRegistry.addToken(tokenAddress, isStable);
  } catch (e) {
    console.error(e);
  }
  callback();
}
