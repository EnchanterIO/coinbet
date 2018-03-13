var Coinbet = artifacts.require("./Coinbet.sol");

contract('TestCoinbet', function(accounts) {
    it("should create successfully betting rounds", async function() {
        let coinbet = await Coinbet.deployed();

        let roundId1 = await coinbet.createBetRound.call(1521504000,1531504000,1541504000,100,2);
        let roundId2 = await coinbet.createBetRound.call(1521504000,1531504000,1541504000,100,2);

        assert.equal(roundId1.valueOf(), 0, "First bet round should have ID 0.")
        // @todo this test is failing, in previous solidity version (not JS) it was working...
        assert.equal(roundId2.valueOf(), 1, "First bet round should have ID 1.")
    });
});