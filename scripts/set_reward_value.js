const VaultRegistry = artifacts.require("VaultRegistry");
const { pressAnyKey } = require('./_utils.js');


module.exports = async (callback) => {
  try {
    const len = process.argv.length;
    const vaultRegistryAddress = process.argv[len - 2];
    const rewardValue = process.argv[len - 1]; // IN USDT

    const vaultRegistry = await VaultRegistry.at(vaultRegistryAddress);

    console.log(`Set total reward to ${rewardValue} USDT for ${vaultRegistryAddress} contract`)
    await pressAnyKey();

    await vaultRegistry.setRewardValue(web3.utils.toWei(rewardValue));
  } catch (e) {
    console.error(e);
  }
  callback();
}
