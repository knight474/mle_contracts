var HRSYToken = artifacts.require("HRSYToken");

var PriceTracker = new Map();

function logPrice(actionName, transaction) {
    if (PriceTracker.get(actionName)) {
        PriceTracker.get(actionName).push(transaction.receipt.gasUsed);
    } else {
        PriceTracker.set(actionName, [transaction.receipt.gasUsed]);
    }
}

//testing the horsey contract
contract('HRSYToken', function (accounts) {

    async function getCost(trans) {
        const tx = await web3.eth.getTransaction(trans.tx);
        return tx.gasPrice.mul(trans.receipt.gasUsed);
    }

    function isEqual(number1, number2) {
        return (number1 < (number2 + 1 * web3.toWei(0.00001, "ether"))) && (number1 > (number2 - 1 * web3.toWei(0.00001, "ether")));
    }

    let owner = accounts[1];
    let defaultUser = accounts[2];
    let defaultUser2 = accounts[3];

    it("contract can deploy", async () => {
        let token = await HRSYToken.new({ from: owner });
        let receipt = await web3.eth.getTransactionReceipt(token.transactionHash);
        PriceTracker.set("contract creation", [receipt.gasUsed]);
    });

    it("owner can change master", async () => {
        let token = await HRSYToken.new({ from: owner });
        let trans = await token.changeMaster(defaultUser, {from : owner});
        logPrice("changeMaster",trans);
        let master = await token.master();
        assert.equal(master.valueOf(),defaultUser);
    });

    it("master can store horsey", async () => {
        let token = await HRSYToken.new({ from: owner });
        await token.changeMaster(defaultUser, {from : owner});
        let trans = await token.storeHorsey(defaultUser2, 666, 1, "DNA", 10, 3, {from : defaultUser});
        logPrice("storeHorsey",trans);
        let horsey = await token.horseys(666);

        assert.equal(horsey[0],"0x444e410000000000000000000000000000000000000000000000000000000000"); //bytes32 'DNA'
        assert.equal(horsey[1], "0x0000000000000000000000000000000000000001");
        assert.equal(""+horsey[2], "10");
        assert.equal(""+horsey[3], "3");
    });

    it("master can modify horsey", async () => {
        let token = await HRSYToken.new({ from: owner });
        await token.changeMaster(defaultUser, { from: owner });
        
        await token.storeHorsey(defaultUser2, 666, 1, "DNA", 10, 3, {from : defaultUser});

        let trans = await token.modifyHorseyDna(666, "DNA2", { from: defaultUser });
        logPrice("modifyHorseyDna",trans);
        trans = await token.modifyHorseyUpgradeCounter(666, 4, { from: defaultUser });
        logPrice("modifyHorseyUpgradeCounter",trans);
        trans = await token.storeName(666, "plop", { from: defaultUser });
        logPrice("storeName",trans);

        let horsey = await token.horseys(666);
        let name = await token.names(666);

        assert.equal(horsey[0],"0x444e413200000000000000000000000000000000000000000000000000000000"); //bytes32 'DNA2'
        assert.equal(""+horsey[2], "10");
        assert.equal(""+horsey[3], "4");
        assert.equal(name, "plop");
    });

    it("master can unstore horsey", async () => {
        let token = await HRSYToken.new({ from: owner });
        await token.changeMaster(defaultUser, { from: owner });
        
        await token.storeHorsey(defaultUser2, 666, 1, "DNA", 10, 3, { from: defaultUser });
        
        let trans = await token.unstoreHorsey(666, { from: defaultUser });
        logPrice("unstoreHorsey",trans);

        let horsey = await token.horseys(666);

        assert.equal(horsey[0],"0x0000000000000000000000000000000000000000000000000000000000000000");
        assert.equal(horsey[1], "0x0000000000000000000000000000000000000000");
        assert.equal(horsey[2], "0");
        assert.equal(horsey[3], "0");
    });

    it("master can unstore horsey with name", async () => {
        let token = await HRSYToken.new({ from: owner });
        await token.changeMaster(defaultUser, { from: owner });
        
        await token.storeHorsey(defaultUser2, 666, 1, "DNA", 10, 3, { from: defaultUser });

        await token.storeName(666, "plop", {from : defaultUser});
        await token.unstoreHorsey(666, {from : defaultUser});
    });

    it("just show gas prices", async () => {
        console.log(PriceTracker);
    })

});