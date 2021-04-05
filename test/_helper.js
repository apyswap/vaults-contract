const truffleAssert = require('truffle-assertions');
const PREFIX = "Returned error: VM Exception while processing transaction:";

class _helper {
  static async tryCatch(promise, errText, errType = "revert") {
    try {
      await promise;
      throw null;
    }
    catch (error) {
      assert(error, "Expected an error but did not get one");
      if (errType) {
        errType = " " + errType;
      }
      let expected = `${PREFIX}${errType} ${errText}`;
      assert(error.message.startsWith(expected), `Expected an error starting with '${expected}' but got '${error.message}' instead`);
    }
  };

  static assertVaultCreatedEvent(tx, address) {
    truffleAssert.eventEmitted(tx, 'VaultCreated', (ev) => {
      return ev.vaultAddress === address;
    });
  }

  static assertLockedEvent(tx, data) {
    truffleAssert.eventEmitted(tx, 'Locked', (ev) => {
      return ev.account === data.account
        && ev.interval.toString() === data.interval.toString()
        && ev.lockedValue.toString() === data.lockedValue.toString()
        && ev.rewardValue.toString() === data.rewardValue.toString();
    });
  }

  static assertUnlockedEvent(tx, account) {
    truffleAssert.eventEmitted(tx, 'Unlocked', (ev) => {
      return ev.account === account;
    });
  }

  static assertWithdrawnEvent(tx, account, share) {
    truffleAssert.eventEmitted(tx, 'Withdrawn', (ev) => {
      return ev.account === account && ev.share.toString() === share;
    });
  }
}

module.exports = {Helper: _helper};
