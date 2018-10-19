pragma solidity ^0.4.24;

import "./WalletUser.sol";
import "../openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "../openzeppelin-solidity/contracts/ownership/Ownable.sol";

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
        Bid memory bid = orders[msg.sender];
        //return the eth
        require(bid.buyer != address(0),"Order not found");
        msg.sender.transfer(msg.sender,bid.value);
        delete orders[msg.sender];
    }
}