const VaultRegistry = artifacts.require("VaultRegistry");
const { pressAnyKey } = require('./_utils.js');


module.exports = async (callback) => {
  try {
    const len = process.argv.length;
    const vaultRegistryAddress = process.argv[len - 3];
    const interval = process.argv[len - 2];
    const reward = process.argv[len - 1];

    const vaultRegistry = await VaultRegistry.at(vaultRegistryAddress);

    console.log(`Add lock for ${interval} sec with ${reward}% reward to ${vaultRegistryAddress}`)
    await pressAnyKey();

    await vaultRegistry.addLock(interval, reward);
  } catch (e) {
    console.error(e);
  }
  callback();
}
