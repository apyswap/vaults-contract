const VaultRegistry = artifacts.require("VaultRegistry");
const { pressAnyKey } = require('./_utils.js');


module.exports = async (callback) => {
  try {
    const len = process.argv.length;
    const vaultRegistryAddress = process.argv[len - 2];
    const rewardTokenAddress = process.argv[len - 1];

    const vaultRegistry = await VaultRegistry.at(vaultRegistryAddress);

    console.log(`Set APYS (${rewardTokenAddress}) as reward token for ${vaultRegistryAddress}`)
    await pressAnyKey();

    await vaultRegistry.setReward(rewardTokenAddress);
  } catch (e) {
    console.error(e);
  }
  callback();
}
