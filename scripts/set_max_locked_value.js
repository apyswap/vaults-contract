const VaultRegistry = artifacts.require("VaultRegistry");
const { pressAnyKey } = require('./_utils.js');


module.exports = async (callback) => {
  try {
    const len = process.argv.length;
    const vaultRegistryAddress = process.argv[len - 2];
    const maxLockedValue = process.argv[len - 1]; // IN USDT

    const vaultRegistry = await VaultRegistry.at(vaultRegistryAddress);

    console.log(`Set max locked value to ${maxLockedValue} USDT for ${vaultRegistryAddress} contract`)
    await pressAnyKey();

    await vaultRegistry.setMaxLockedValue(web3.utils.toWei(maxLockedValue));
  } catch (e) {
    console.error(e);
  }
  callback();
}
