var Betting = artifacts.require("Betting");
var Validator = artifacts.require("RaceValidator");

var PriceTracker = new Map();

function logPrice(actionName, transaction) {
    if (PriceTracker.get(actionName)) {
        PriceTracker.get(actionName).push(transaction.receipt.gasUsed);
    } else {
        PriceTracker.set(actionName, [transaction.receipt.gasUsed]);
    }
}

//testing the horsey contract
contract('HorseyToken', function (accounts) {
    /*
        HELPERS
    */
    function hex2a(hexx) {
        var hex = hexx.toString();//force conversion
        var str = '';
        for (var i = 2; (i < hex.length && hex.substr(i, 2) !== '00'); i += 2)
            str += String.fromCharCode(parseInt(hex.substr(i, 2), 16));
        return str;
    }

    async function getCost(trans) {
        const tx = await web3.eth.getTransaction(trans.tx);
        return tx.gasPrice.mul(trans.receipt.gasUsed);
    }

    let owner = accounts[1];
    let defaultUser = accounts[2];

    it("should be able to initialize contract", async () => {
        let validator = await Validator.new({ from: defaultUser });
        let receipt = await web3.eth.getTransactionReceipt(validator.transactionHash);
        PriceTracker.set("contract creation", [receipt.gasUsed]);
    });

    it("should be able to claim if winner", async () => {
        let validator = await Validator.new({ from: defaultUser });
        let race = await Betting.new({ from: owner });
        await race.addBet("ETH", 10, { from: defaultUser }); //add a bet for us on ETH for 10 ETH
        await race.setEnded("ETH");
        await validator.validateWinner(race.address,defaultUser);
    });

    it("should not be able to validate with address of not a race contract", async () => {
        let validator = await Validator.new({ from: defaultUser });
        
        try {
            await validator.validateWinner(accounts[9],defaultUser);
            assert.ok(false); //should never reach that
        } catch (err) {
            assert.ok(true);
        }
    });

    it("should not be able to claim if race not ended", async () => {
        let validator = await Validator.new({ from: defaultUser });
        let race = await Betting.new({ from: owner });
        await race.addBet("ETH", 10, { from: defaultUser }); //add a bet for us on ETH for 10 ETH

        try {
            await validator.validateWinner(race.address,defaultUser);
            assert.ok(false); //should never reach that
        } catch (err) {
            assert.ok(true);
        }
    });

    it("should not be able to claim if not a winner", async () => {
        let validator = await Validator.new({ from: defaultUser });
        let race = await Betting.new({ from: owner });
        await race.addBet("BTC", 10, { from: defaultUser }); //add a bet for us on ETH for 10 ETH
        await race.addBet("ETH", 10, { from: accounts[9] }); //add a bet for us on ETH for 10 ETH
        await race.setEnded("ETH");

        try {
            await validator.validateWinner(race.address,defaultUser);
            assert.ok(false); //should never reach that
        } catch (err) {
            assert.ok(true);
        }
    });

    it("should not be able to claim if refunded", async () => {
        let validator = await Validator.new({ from: defaultUser });
        let race = await Betting.new({ from: owner });
        await race.addBet("ETH", 10, { from: defaultUser }); //add a bet for us on ETH for 10 ETH
        await race.setVoided(true);
        await race.setEnded("ETH");
        try {
            await validator.validateWinner(race.address,defaultUser);
            assert.ok(false); //should never reach that
        } catch (err) {
            assert.ok(true);
        }
    });

   

    it("should not be able to claim twice", async () => {
        let validator = await Validator.new({ from: defaultUser });
        let race = await Betting.new({ from: owner });
        await race.addBet("ETH", 10, { from: defaultUser }); //add a bet for us on ETH for 10 ETH
        await race.setEnded("ETH");
        await validator.validateWinner(race.address,defaultUser);
        try {
            await validator.validateWinner(race.address,defaultUser);
            assert.ok(false); //should never reach that
        } catch (err) {
            assert.ok(true);
        }
    
    });

    it("dummy", async () => {
        console.log(PriceTracker);
    });
});