pragma solidity ^0.4.24;

import "./WalletUser.sol";
import "../openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "../openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "../openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

/**
    @title An auction system to sell budnles of HORSE tokens
*/

contract HorseAuction is Ownable, Pausable {

    /**
        @dev Represents a bid a user makes to buy HORSE
    */
    struct Bid {
        uint256 amount; // amount of HORSE to buy
        address buyer;  // buyers address
    }

    struct Bundle {
        uint256 amount;
        uint256 expires;
        uint256 timestamp;
        address seller;

        uint256 currentBid;
        address highestBidder;
    }

   /// @dev horse token access interface
    IERC20 public horseToken = IERC20(0x5B0751713b2527d7f002c0c4e2a37e1219610A6B);

    mapping(bytes32 => Bundle) public bundles;
    uint256 public feesQuot = 15;
    uint256 fees;

    event NewBundle(uint256 amount, uint256 duration, bytes32 id);
    event NewBid(bytes32 bundleId, uint256 currentValue);
    event AuctionEnded(bytes32 id);

    /**
        @dev Contracts constructor
    */
    constructor() public
    Ownable()
    Pausable() {
       
    }

    function changeFees(uint256 newFees) external 
    onlyOwner() {
        feesQuot = newFees;
    }

    function sell(uint256 amount, uint256 duration) external {
        //set minimal amount to be 10K to avoid bundle spamming
        require(amount >= 10000, "At least 10000 HORSE at a time");
        require(duration > 5 minutes, "Duration must be at least 5 minutes");

        bytes32 bundleId = keccak256(abi.encodePacked(amount, duration, msg.sender, block.timestamp));
        //make sure we wont destroy an existing bundle (if same amount, seller and duration and executed in the same block!)
        require(bundles[bundleId].seller == address(0),"You cant create twice the same bundle in a single block");
        Bundle storage newBundle = bundles[bundleId];
        newBundle.amount = amount;
        
        newBundle.timestamp = block.timestamp;
        newBundle.expires = newBundle.timestamp+duration;
        newBundle.seller = msg.sender;
        
        require(horseToken.transferFrom(msg.sender, address(this), amount),"Transfer failed, are we approved to transferFrom this amount?");

        emit NewBundle(amount, duration, bundleId);
    }

    function bid(bytes32 bundleId) external payable 
    _exists(bundleId)
    _active(bundleId) {
        Bundle storage bundle = bundles[bundleId];
        require(bundle.currentBid < msg.value, "You must bid higher than the current value");
        //if not first bidder, send back the losers ETH!
        if(bundle.highestBidder != address(0)) {
            bundle.highestBidder.transfer(bundle.currentBid);
        }
        
        bundle.currentBid = msg.value;
        bundle.highestBidder = msg.sender;
        
        emit NewBid(bundleId, msg.value);
    }

    function getFeesAmount(bytes32 bundleId) external view
    _exists(bundleId)
    _expired(bundleId) 
    returns (uint256) {
        return bundles[bundleId].currentBid / 1000 * feesQuot;
    }

    function withdrawBundle(bytes32 bundleId) external 
    _exists(bundleId)
    _expired(bundleId) {
        Bundle storage bundle = bundles[bundleId];
        //did we get any bids?
        if(bundle.currentBid > 0) {
            //compute the amount to keep
            uint256 fee = bundle.currentBid / 1000 * feesQuot;
            //give the seller his ETH
            bundle.seller.transfer(bundle.currentBid-fee);
            fees = fees + fee;
            //give the buyer his HORSE
            require(horseToken.transfer(bundle.highestBidder, bundle.amount),"Transfer failed");
        } else {
            //just give me back my horse
            require(horseToken.transfer(bundle.seller, bundle.amount),"Transfer failed");
        }
        
        delete(bundles[bundleId]);
        emit AuctionEnded(bundleId);
    }

    function withdraw() external
    onlyOwner() {
        msg.sender.transfer(fees);
        fees = 0;
    }

    modifier _exists(bytes32 bundleId) {
        require(bundles[bundleId].seller != address(0), "Bundle not found");
        _;
    }

    modifier _expired(bytes32 bundleId) {
        require(block.timestamp > bundles[bundleId].expires,"Auction is still active");
        _;
    }

    modifier _active(bytes32 bundleId) {
        require(block.timestamp <= bundles[bundleId].expires,"Auction expired");
        _;
    }

}