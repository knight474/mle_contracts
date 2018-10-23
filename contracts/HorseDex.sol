pragma solidity ^0.4.24;

import "./WalletUser.sol";
import "../openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "../openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "../openzeppelin-solidity/contracts/math/SafeMath.sol";


interface EtherDelta {
    function deposit() payable external;
    function withdrawToken(address token, uint256 amount) external;
    function trade(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce, address user, uint8 v, bytes32 r, bytes32 s, uint amount) external;
}

/**
    @title A decentralized exchange for the ETH/HORSE pair
*/

contract HorseDex is WalletUser, Ownable, Pausable {

    event OrderPlaced(address indexed buyer, uint256 amount, uint256 value);
    event OrderCanceled(address indexed buyer);
    event OrderRejected(address indexed buyer);
    event OrderProcessed(address indexed buyer, uint256 amount, uint256 price);

    /**
        @dev Represents a bid a user makes to buy HORSE
    */
    struct Bid {
        uint256 amount; // amount of HORSE to buy
        uint256 value;  // amount of ETH to pay for the HORSE
        address buyer;  // buyers address
    }

    ///@dev Maps buyers to their orders/bids
    mapping(address => Bid) public orders;

    EtherDelta public tradeContract = EtherDelta(0x8d12A197cB00D4747a1fe03395095ce2A5CC6819);

    /**
        @dev Contracts constructor
        @param walletAddress Address of the current wallet contract
    */
    constructor(address walletAddress) public
    WalletUser(walletAddress)
    Ownable()
    Pausable() {
       
    }

    /**
        @dev Places a new order for the sender for amount HORSE
        Price is determined by msg.value
        @param amount Amount of HORSE to buy
    */
    function placeOrder(uint256 amount) external payable {
        require(msg.value > 0,"Non zero price only");
        Bid storage bid = orders[msg.sender];
        ///@dev only 1 order per user with the same amount allowed
        require(bid.buyer == address(0),"One order per user at a time");
        bid.amount = amount;
        bid.value = msg.value;
        bid.buyer = msg.sender;

        emit OrderPlaced(msg.sender, amount, msg.value);
    }

    /**
        @dev Allows a buyer to cancel his own order
    */
    function cancelOrder() external {
        _removeOrder(msg.sender);
        emit OrderCanceled(msg.sender);
    }

    /**
        @dev Used by the owner (server) to reject an order if price isnt agreeable
        @param buyer The order creator
    */
    function rejectOrder(address buyer) external 
    onlyOwner() {
        _removeOrder(buyer);
        emit OrderRejected(buyer);
    }

    /**
        @dev Called by the server to purchase HORSE from etherdelta (forkdelta)
        Uses the collected ETH to buy HORSE
        Has to be called for each order to purchase from
        @param amountGet Sellers order data
        @param amountGive Sellers order data
        @param expires Sellers order data
        @param nonce Sellers order data
        @param user Sellers order data
        @param v Sellers order data
        @param r Sellers order data
        @param s Sellers order data
        @param amount The amount of HORSE to buy
    */
    function purchaseHORSE(uint amountGet, uint amountGive, uint expires, uint nonce, address user, uint8 v, bytes32 r, bytes32 s, uint amount) external
    onlyOwner() {
        //compute the amount of ETH to pay in order to acquire "amount" HORSE from this order at this price
        //deposit the right amount of ETH to EtherDelta for this trade
        tradeContract.deposit.value(SafeMath.div(SafeMath.mul(amountGive,amount),amountGet))();
        //buy amountGet quantity of HORSE token using amountGive ETH (token 0x0 = ETH currency) + the sellers order data
        tradeContract.trade(0x5B0751713b2527d7f002c0c4e2a37e1219610A6B, amountGet, 0x0, amountGive, expires, nonce, user, v, r, s, amount);
        //withdraw the bought tokens from etherdelta
        tradeContract.withdrawToken(0x5B0751713b2527d7f002c0c4e2a37e1219610A6B, amountGet);
        //send the bought tokens to the pool
        _horseToken.transfer(address(_wallet),amountGet);
    }

    /**
        @dev Used by the owner (server) to fulfill an order if price is agreeable
        @param buyer the address of the lucky buyer
    */
    function processOrder(address buyer) external
    onlyOwner() {
        Bid memory bid = orders[msg.sender];
        //return the eth
        require(bid.buyer != address(0),"Order not found");
        //transfer HORSE to this user
        _wallet.transferFromAndTo(address(_wallet),buyer,bid.amount);
    
        emit OrderProcessed(buyer,bid.amount,bid.value/bid.amount);

        //remove the pending order
        delete orders[msg.sender];
    }

    /**
        @dev Internal function to remove an order and give the buyer back his ETH
        @param buyer The order creator
    */
    function _removeOrder(address buyer) internal {
        Bid memory bid = orders[buyer];
        //return the eth
        require(bid.buyer != address(0),"Order not found");
        msg.sender.transfer(bid.value);
        delete orders[msg.sender];
    }
}