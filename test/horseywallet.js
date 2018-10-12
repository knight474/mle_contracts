var Wallet = artifacts.require("HorseyWallet");
var FakeERC20 = artifacts.require("FakeERC20");

var PriceTracker = new Map();

function logPrice(actionName, transaction) {
    if (PriceTracker.get(actionName)) {
        PriceTracker.get(actionName).push(transaction.receipt.gasUsed);
    } else {
        PriceTracker.set(actionName, [transaction.receipt.gasUsed]);
    }
}

//testing the horsey contract
contract('HorseyWallet', function (accounts) {

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
    let defaultUser3 = accounts[4];
    let oneHorse = web3.toWei(1, "ether") * 1;

    let HORSE = 0;

    it("initial creation of fake ERC20", async () => {
        HORSE = await FakeERC20.new({ from: defaultUser }); //owner owns now 1* 10^18 FakeHORSE ERC20 tokens
        await HORSE.transfer(defaultUser2, oneHorse * 100,{ from: defaultUser });
    });


    it("contract can deploy", async () => {
        let wallet = await Wallet.new(HORSE.address,{ from: owner });
        let receipt = await web3.eth.getTransactionReceipt(wallet.transactionHash);
        PriceTracker.set("contract creation", [receipt.gasUsed]);
    });

    it("can add funds", async () => {
        let wallet = await Wallet.new(HORSE.address, { from: owner });
        await HORSE.approve(wallet.address, oneHorse * 10, { from: defaultUser });
        let trans = await wallet.addFunds(oneHorse*10, { from: defaultUser }); //add 10 HORSE
        logPrice("addFunds",trans);
    });

    it("cant add funds if not approved", async () => {
        let wallet = await Wallet.new(HORSE.address, { from: owner });
        //await HORSE.approve(wallet.address, oneHorse * 10, { from: defaultUser });
        try {
            await wallet.addFunds(oneHorse * 10, { from: defaultUser }); //add 10 HORSE
            assert.ok(false); //should never reach that
        } catch (err) {
            assert.ok(true);
        }
    });

    it("can deposit funds", async () => {
        let wallet = await Wallet.new(HORSE.address, { from: owner });
        let balanceBefore = await wallet.balanceOf(defaultUser2);
        await HORSE.approve(wallet.address, oneHorse * 10, { from: defaultUser2 });
        let trans = await wallet.deposit(oneHorse*10, { from: defaultUser2 }); //add 10 HORSE
        logPrice("deposit", trans);
        let balanceAfter = await wallet.balanceOf(defaultUser2);
        assert.equal("" + balanceBefore, "0");
        assert.equal("" + balanceAfter, "10000000000000000000");
    });

    it("can withdraw funds", async () => {
        let wallet = await Wallet.new(HORSE.address, { from: owner });
        let balanceBefore = await HORSE.balanceOf(defaultUser2);
        await HORSE.approve(wallet.address, oneHorse * 10, { from: defaultUser2 });
        await wallet.deposit(oneHorse*10, { from: defaultUser2 }); //add 10 HORSE
        let trans = await wallet.withdraw(oneHorse*10, { from: defaultUser2 }); //withdraw 10 HORSE
        logPrice("withdraw", trans);
        let balanceAfter = await HORSE.balanceOf(defaultUser2);
        //balance should be the same
        assert.equal(""+balanceBefore,""+balanceAfter);
    });

    it("spender can transfer funds at will", async () => {
        let wallet = await Wallet.new(HORSE.address, { from: owner });
        let balanceBefore = await wallet.balanceOf(owner);
        await HORSE.approve(wallet.address, oneHorse * 10, { from: defaultUser2 });
        await wallet.deposit(oneHorse * 10, { from: defaultUser2 }); //add 10 HORSE
        let trans = await wallet.addApprovedSpender(owner, { from: owner });
        logPrice("addApprovedSpender", trans);
        trans = await wallet.transferFromAndTo(defaultUser2,owner,oneHorse*10, { from: owner });
        logPrice("transferFromAndTo", trans);
        let balanceAfter = await wallet.balanceOf(owner);
        assert.equal("" + balanceBefore, "0");
        assert.equal(""+balanceAfter,"10000000000000000000");
    });

    it("spender can credit HXP", async () => {
        let wallet = await Wallet.new(HORSE.address, { from: owner });
        await wallet.addApprovedSpender(owner, { from: owner });
        let balanceBefore = await wallet.balanceOfHXP(defaultUser2);
        let trans = await wallet.creditHXP(defaultUser2,1000, { from: owner }); //add 1000 HXP
        logPrice("creditHXP", trans);
        let balanceAfter = await wallet.balanceOfHXP(defaultUser2);
        assert.equal("" + balanceBefore, "0");
        assert.equal("" + balanceAfter, "1000");
    });

    it("spender can remove HXP", async () => {
        let wallet = await Wallet.new(HORSE.address, { from: owner });
        await wallet.addApprovedSpender(owner, { from: owner });
        let balanceBefore = await wallet.balanceOfHXP(defaultUser2);
        let trans = await wallet.creditHXP(defaultUser2,1000, { from: owner }); //add 1000 HXP
        await wallet.spendHXP(defaultUser2,500, { from: owner }); //remove 500 HXP
        logPrice("spendHXP", trans);
        let balanceAfter = await wallet.balanceOfHXP(defaultUser2);
        assert.equal("" + balanceBefore, "0");
        assert.equal("" + balanceAfter, "500");
    });

    it("just show gas prices", async () => {
        console.log(PriceTracker);
    })

  
});