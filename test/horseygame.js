var HorseyGame = artifacts.require("HorseyGame");
var HRSYToken = artifacts.require("HRSYToken");
var Betting = artifacts.require("Betting");
var Wallet = artifacts.require("HorseyWallet");
var FakeERC20 = artifacts.require("FakeERC20");
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

    function isEqual(number1, number2) {
        return (number1 < (number2 + 1 * web3.toWei(0.00001, "ether"))) && (number1 > (number2 - 1 * web3.toWei(0.00001, "ether")));
    }

    let owner = accounts[1];
    let defaultUser = accounts[2];
    let defaultUser2 = accounts[3];
    let oneHorse = web3.toWei(1, "ether") * 1;

    let HORSE = 0;
    let VALIDATOR = 0;
    let token;
    let wallet;
    let game;
    it("initial creation of fake ERC20", async () => {
        HORSE = await FakeERC20.new({ from: defaultUser }); //owner owns now 1* 10^18 FakeHORSE ERC20 tokens
        VALIDATOR = await Validator.new({ from: defaultUser });
        await HORSE.transfer(defaultUser2, oneHorse * 10000,{ from: defaultUser });
    });
    
    it("should be able to initialize contract", async () => {
        token = await HRSYToken.new({ from: owner });
        wallet = await Wallet.new(HORSE.address,{ from: owner });
        game = await HorseyGame.new(token.address,VALIDATOR.address,wallet.address, {from : owner});
        let receipt = await web3.eth.getTransactionReceipt(game.transactionHash);
        PriceTracker.set("game contract creation", [receipt.gasUsed]);
        receipt = await web3.eth.getTransactionReceipt(wallet.transactionHash);
        PriceTracker.set("wallet contract creation", [receipt.gasUsed]);
        receipt = await web3.eth.getTransactionReceipt(token.transactionHash);
        PriceTracker.set("token contract creation", [receipt.gasUsed]);

        

        await token.changeMaster(game.address, { from: owner });
        await wallet.addApprovedSpender(game.address, { from: owner });
        await wallet.addApprovedSpender(owner, { from: owner });
        await HORSE.approve(wallet.address, oneHorse * 1000, { from: defaultUser });
        await wallet.addFunds(oneHorse * 1000, { from: defaultUser }); //wallet needs a pool fund
        await HORSE.approve(wallet.address, oneHorse * 1000, { from: defaultUser2 });
        await wallet.deposit(oneHorse * 1000, { from: defaultUser2 }); //deposit 1000 HORSE from defaultUser2 to HIS wallet

        //give some HXP to all test accounts
        wallet.creditHXP(defaultUser, 99999999, { from: owner });
        wallet.creditHXP(defaultUser2,99999999, { from: owner });
    });

    it("should be able to change fees", async () => {  
        let cost = await game.config("RENAMEFEE");
        var value = web3.toWei(1.5, "ether");
        //make it cost 1 eth
        //these should all be ok
        trans = await game.setConfigValue("RENAMEFEE",value, { from: owner });
        logPrice("setConfigValue", trans);

        let newCost = await game.config("RENAMEFEE");

        assert.ok(newCost.valueOf() != cost.valueOf());
        assert.ok(newCost.valueOf() == web3.toWei(1.5, "ether"));
    });

    it("should be able to claim", async () => {
        let race = await Betting.new({ from: owner });
        await race.setEnded("ETH");
        await race.addBet("ETH", web3.toWei(10, "ether"), { from: defaultUser2 }); //add a bet for us on ETH for 10 ETH
        let walletBalanceBefore = await wallet.balanceOf(defaultUser2);
        let trans = await game.claim(race.address, { from: defaultUser2 });
        logPrice("claim", trans);
        let walletBalanceAfter = await wallet.balanceOf(defaultUser2);
        let claimFee = await game.config("CLAIMFEE");
        let balance = await token.balanceOf(defaultUser2);
        assert.equal("" + balance, "1");
        assert.equal(walletBalanceBefore, walletBalanceAfter*1 + claimFee*1);
    });    
 
    it("should be able to burn a normal horsey", async () => {
        let race = await Betting.new({ from: owner });
        await race.setEnded("ETH");
        await race.addBet("ETH", web3.toWei(10, "ether"), { from: defaultUser2 }); //add a bet for us on ETH for 10 ETH
        
        let trans = await game.claim(race.address, { from: defaultUser2 });
        
        let tokenId = trans.logs[0].args.tokenId;
        let burnFee = await game.config("BURNFEE0");
        let burnRWRD = await game.config("BURN0");
        let poolBalanceBefore = await wallet.balanceOf(wallet.address);
        let hxpBalanceBefore = await wallet.balanceOfHXP(defaultUser2);
        trans = await game.burn(tokenId, { from: defaultUser2 });
        let poolBalanceAfter = await wallet.balanceOf(wallet.address);
        let hxpBalanceAfter = await wallet.balanceOfHXP(defaultUser2);
        logPrice("burn", trans);
        assert.equal(poolBalanceAfter * 1, poolBalanceBefore * 1 + burnFee * 1);
        assert.equal(hxpBalanceAfter * 1, hxpBalanceBefore * 1 + burnRWRD * 1);
    });      

    it("should be able to upgrade", async () => {
        let race = await Betting.new({ from: owner });
        await race.setEnded("ETH");
        await race.addBet("ETH", web3.toWei(10, "ether"), { from: defaultUser2 }); //add a bet for us on ETH for 10 ETH
        
        let trans = await game.claim(race.address, { from: defaultUser2 });
        let tokenId = trans.logs[0].args.tokenId;

        let fee = await game.config("UPGR0");
        let upgrFee = await game.config("UPGRFEE");

        let poolBalanceBefore = await wallet.balanceOf(wallet.address);

        let balanceHXPBefore = await wallet.balanceOfHXP(defaultUser2);
        trans = await game.upgrade(tokenId, { from: defaultUser2 });
        logPrice("upgrade", trans);
        let balanceHXPAfter = await wallet.balanceOfHXP(defaultUser2);
        assert.equal(balanceHXPAfter, balanceHXPBefore * 1 - fee * 1);
        
        balanceHXPBefore = await wallet.balanceOfHXP(defaultUser2);
        trans = await game.upgrade(tokenId, { from: defaultUser2 });
        logPrice("upgrade", trans);
        balanceHXPAfter = await wallet.balanceOfHXP(defaultUser2);
        fee = await game.config("UPGR1");
        assert.equal(balanceHXPAfter, balanceHXPBefore * 1 - fee * 1);
        
        balanceHXPBefore = await wallet.balanceOfHXP(defaultUser2);
        trans = await game.upgrade(tokenId, { from: defaultUser2 });
        logPrice("upgrade", trans);
        balanceHXPAfter = await wallet.balanceOfHXP(defaultUser2);
        fee = await game.config("UPGR2");
        assert.equal(balanceHXPAfter, balanceHXPBefore * 1 - fee * 1);
        
        balanceHXPBefore = await wallet.balanceOfHXP(defaultUser2);
        trans = await game.upgrade(tokenId, { from: defaultUser2 });
        logPrice("upgrade", trans);
        balanceHXPAfter = await wallet.balanceOfHXP(defaultUser2);
        fee = await game.config("UPGR3");
        assert.equal(balanceHXPAfter, balanceHXPBefore * 1 - fee * 1);
        
        let poolBalanceAfter = await wallet.balanceOf(wallet.address);

        assert.equal(poolBalanceAfter * 1 - upgrFee * 4, poolBalanceBefore);
    });

    it("should be able to rename", async () => {
        let race = await Betting.new({ from: owner });
        await race.setEnded("ETH");
        await race.addBet("ETH", web3.toWei(10, "ether"), { from: defaultUser2 }); //add a bet for us on ETH for 10 ETH
        
        let trans = await game.claim(race.address, { from: defaultUser2 });
        let tokenId = trans.logs[0].args.tokenId;

        let fee = await game.config("RENAMEFEE");

        let poolBalanceBefore = await wallet.balanceOf(wallet.address);
        trans = await game.rename(tokenId, "FAFNIR", { from: defaultUser2 });
        let poolBalanceAfter = await wallet.balanceOf(wallet.address);
        logPrice("rename", trans);
        assert.equal(poolBalanceAfter*1,poolBalanceBefore*1+fee*6);
        
        let horsey = await game.getHorsey(tokenId);
        assert.equal(horsey[3],"FAFNIR");
    });

    it("should be able to purchase HXP", async () => {
        let hxpBefore = await wallet.balanceOfHXP(defaultUser2);
        let trans = await game.purchaseHXP(1000, {from : defaultUser2});
        logPrice("purchaseHXP", trans);
        let hxpAfter = await wallet.balanceOfHXP(defaultUser2);
        assert.equal(hxpAfter*1,hxpBefore*1+1000);
    });

    it("should be able to claim from a RWRD horsey", async () => {
        let race = await Betting.new({ from: owner });
        await race.setEnded("ETH");
        await race.addBet("ETH", web3.toWei(10, "ether"), { from: defaultUser2 }); //add a bet for us on ETH for 10 ETH
        
        let trans = await game.claim(race.address, { from: defaultUser2 });
        let tokenId = trans.logs[0].args.tokenId;

        trans = await game.upgrade(tokenId, { from: defaultUser2 });//make it rare
        trans = await game.upgrade(tokenId, { from: defaultUser2 });//make it RWRD lvl1
       
        let race2 = await Betting.new({ from: owner });
        await race2.setEnded("ETH");
        await race2.addBet("ETH", web3.toWei(10, "ether"), { from: defaultUser2 }); //add a bet for us on ETH for 10 ETH
        await game.claim(race2.address, { from: defaultUser2 });

        await game.claimRWRD(tokenId, { from: defaultUser2 });
    });
    
    it("dummy", async () => {
        console.log(PriceTracker);
    });
});