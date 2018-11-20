pragma solidity ^0.4.25;

import "../openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "../openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "../openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

/**
    @title An auction system to sell budnles of HORSE tokens
*/

contract HorseAuction is Ownable, Pausable {
    uint256 constant MINIMAL_DURATION = 5 minutes; //minimum auction duration is 5 minutes

    /**
        @dev An auctionable ERC20 token
    */
    struct ERC20Token {
        address contractAddress;    //address of the token contract
        uint256 minimum;            //minimum bundle amount
        bool allowed;               //set to true if auctioning is allowed
    }

    /**
        @dev Auction bundle containing HORSE
    */
    struct Bundle {
        uint256 amount;         //amount of HORSE in this bundle
        uint256 expires;        //date at which this bundle can no longer be bet on
        uint256 currentBid;     //current bid value
        address seller;         //address of the seller
        address highestBidder;  //address of the current highest bidder
        address token;          //address of the token contract
    }

    /// @dev matches a bundle id to the bundle
    mapping(bytes32 => Bundle) public bundles;

    /// @dev list of all accepted tokens
    mapping(bytes32 => ERC20Token) public tokens;

    /// @dev this is the devs equity expressed in /1000
    uint256 private _commission = 15;

    /// @dev total amount of fees this contract holds
    uint256 private _collected;

    event NewBundle(bytes32 tokenName, uint256 amount, uint256 duration, bytes32 id);
    event NewBid(bytes32 bundleId, uint256 currentValue);
    event AuctionEnded(bytes32 id);
    event TokenRegistered(bytes32 name);
    event TokenRemoved(bytes32 name);

    /**
        @dev Constructor
        Contract can be paused
    */
    constructor() public
    Ownable()
    Pausable() {
       
    }
    /**
        @dev contract owner can change fees
        Fees are expressed /1000
        @param newCommission the new fees in /1000
    */
    function changeCommission(uint256 newCommission) external 
    onlyOwner() {
        _commission = newCommission;
    }

    /** @dev Register a new token in the auctionable token list
        @param token ERC20 token address
        @param name A short token name. ie. HORSE
        @param minimum Minimal auctionable amount
     */
    function registerToken(address token, bytes32 name, uint256 minimum) external
    onlyOwner() {
        require(token != address(0), "Token contract address is null");
        require(name != bytes32(""), "Token must have a unique name");
        require(minimum > 0, "Minimum auctionable amount must be greater than zero");
        require(tokens[name].contractAddress == address(0),"A token with this name already exists");
        ERC20Token storage newToken = tokens[name];
        newToken.contractAddress = token;
        newToken.minimum = minimum;
        newToken.allowed = true;
        emit TokenRegistered(name);
    }

    /** @dev Unregister a token from the auctionable token list
        @param name A short token name. ie. HORSE
     */
    function removeToken(bytes32 name) external
    onlyOwner() {
        require(tokens[name].contractAddress != address(0),"Token not found");
        tokens[name].allowed = false;

        emit TokenRemoved(name);
    }

    /** @dev Change the minimum auctionable amount of a token
        @param name A short token name. ie. HORSE
        @param minimum Minimal auctionable amount
     */
    function configureToken(bytes32 name, uint256 minimum) external
    onlyOwner() {
        require(tokens[name].contractAddress != address(0),"Token not found");
        tokens[name].minimum = minimum;
    }

    /**
        @dev creates a bundle of HORSE to put on auction for a certain duration
        @param tokenName Name of the token to sell
        @param amount The amount of HORSE to include in the bundle
        @param duration Duration of the auction in seconds
    */
    function sell(bytes32 tokenName, uint256 amount, uint256 duration) external 
    whenNotPaused() {
        //set minimal amount to avoid bundle spamming
        require(tokens[tokenName].contractAddress != address(0),"Token not found");
        require(tokens[tokenName].allowed,"Token auctioning is not allowed");
        require(amount >= tokens[tokenName].minimum, "Not enough Tokens in this bundle");
        require(duration > MINIMAL_DURATION, "Duration is too short");
        //bundle ID is the sha of amount + duration + seller address + current block timestamp
        bytes32 bundleId = keccak256(abi.encodePacked(tokenName, amount, duration, msg.sender, block.timestamp));
        //make sure we wont destroy an existing bundle (if same amount, seller and duration and executed in the same block!)
        require(bundles[bundleId].seller == address(0),"You cant create twice the same bundle in a single block");

        Bundle storage newBundle = bundles[bundleId];
        newBundle.token = tokens[tokenName].contractAddress;
        newBundle.amount = amount;
        newBundle.expires = block.timestamp + duration;
        newBundle.seller = msg.sender;
        //transfer the required amount of HORSE from the seller to this contract
        //the seller must approve this transfer first of course!
        require(IERC20(tokens[tokenName].contractAddress).transferFrom(msg.sender, address(this), amount),"Transfer failed, are we approved to transferFrom this amount?");

        emit NewBundle(tokenName, amount, duration, bundleId);
    }

    /**
        @dev Add a new bid on a specific bundle
        @param bundleId ID of the bundle to bid on
        Bundle must exist and auction must not have expired
    */
    function bid(bytes32 bundleId) external payable 
    _exists(bundleId)
    _active(bundleId) 
    whenNotPaused() {
        Bundle storage bundle = bundles[bundleId];
        //Bidder must outbid the previous bidder
        require(bundle.currentBid < msg.value, "You must outbid the current value");

        //if not first bidder, send back the losers ETH!
        if(bundle.highestBidder != address(0)) {
            bundle.highestBidder.transfer(bundle.currentBid);
        }
        
        //replace the older highest bidder
        bundle.currentBid = msg.value;
        bundle.highestBidder = msg.sender;
        
        emit NewBid(bundleId, msg.value);
    }

    /**
        @dev Allows to withdraw a bundle from a completed auction
        Must exist and auction must have ended
        Can be called even while contract is paused
        @param bundleId ID of te bundle to withdraw
    */
    function withdrawBundle(bytes32 bundleId) external 
    _exists(bundleId)
    _expired(bundleId) {
        Bundle memory bundle = bundles[bundleId];
        address to = bundle.highestBidder;
        uint256 what = bundle.amount;
        IERC20 token = IERC20(bundle.token);
        //did we get any bids?
        if(bundle.currentBid > 0) {
            //compute the amount to keep
            uint256 commission = bundle.currentBid / 1000 * _commission;
            //give the seller his ETH
            bundle.seller.transfer(bundle.currentBid-commission);
            _collected = _collected + commission;
        } else {
            //just give me back my token
            to = bundle.seller;
        }

        //prevent reentrancy by deleting the bundle before calling transfer function
        delete(bundles[bundleId]);
        require(token.transfer(to, what),"Transfer failed");
        
        emit AuctionEnded(bundleId);
    }

    /**
        @dev Contract owner can withdraw collected auction fees
    */
    function withdraw() external
    onlyOwner() {
        msg.sender.transfer(_collected);
        _collected = 0;
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