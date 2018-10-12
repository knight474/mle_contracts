pragma solidity ^0.4.24;

import "../openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "../openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "../openzeppelin-solidity/contracts/token/ERC721/ERC721Holder.sol";
import "../openzeppelin-solidity/contracts/token/ERC721/IERC721.sol";
import "./interfaces/IHRSYToken.sol";
import "./WalletUser.sol";

/**
    @dev HorseyExchange contract - handles horsey market exchange which
    includes the following set of functions:
    1. Deposit to Exchange
    2. Cancel sale
    3. Purchase token
**/
contract HorseyExchange is WalletUser, Pausable, Ownable, ERC721Holder { //also Ownable

    event HorseyDeposit(uint256 indexed tokenId, uint256 price);
    event SaleCanceled(uint256 indexed tokenId);
    event HorseyPurchased(uint256 indexed tokenId, address newOwner, uint256 totalToPay);

    /// @dev Fee applied to market maker - measured as percentage
    uint256 public marketMakerFee = 3;

    /// @dev Fee applied to market maker - measured as percentage
    uint256 public devEquity = 50;

    /// @dev  HRSY TOKEN
    IERC721 public HRSYToken;

    /**
        @dev used to store the price and the owner address of a token on sale
    */
    struct SaleData {
        uint256 price;
        address owner;
    }

    /// @dev Market spec to lookup price and original owner based on token id
    mapping (uint256 => SaleData) market;

    /// @dev mapping of current tokens on market by owner
    mapping (address => uint256[]) userBarn;

    /**
        @dev Creates a new HorseyExchange contract
            This is the market to exchange HRSY tokens
        @param walletAddress address of the Horsey wallet to use for purchases and fees
        @param tokenAddress address of the HRSY token contract
    */
    constructor(address walletAddress, address tokenAddress) 
    WalletUser(walletAddress) 
    Pausable() 
    Ownable() 
    ERC721Holder() public {
        require(tokenAddress != address(0),"Invalid HRSY token address!");
        HRSYToken = IERC721(tokenAddress);
    }

    /**
        @dev Allows the owner to change market fees
        @param fees The new fees to apply (can be zero)
    */
    function setMarketFees(uint256 fees) external
    onlyOwner()
    {
        marketMakerFee = fees;
    }

    /**
        @dev Allows the owner to change dev equities
        @param equity The new equity to apply (can be zero)
    */
    function setDevEquity(uint256 equity) external
    onlyOwner()
    {
        devEquity = equity;
    }

    /// @return the tokens on sale based on the user address
    function getTokensOnSale(address user) external view returns(uint256[]) {
        return userBarn[user];
    }

    /// @return the token price with the fees
    function getTokenPrice(uint256 tokenId) public view
    isOnMarket(tokenId) returns (uint256) {
        return market[tokenId].price + (market[tokenId].price / 100 * marketMakerFee);
    }

    /**
        @dev User sends token to sell to exchange - at this point the exchange contract takes
            ownership, but will map token ownership back to owner for auotmated withdraw on
            cancel - requires that user is the rightful owner and is not
            asking for a null price
    */
    function depositToExchange(uint256 tokenId, uint256 price) external
    whenNotPaused()
    isTokenOwner(tokenId)
    nonZeroPrice(price){
        require(HRSYToken.getApproved(tokenId) == address(this),"Exchange is not allowed to transfer");
        uint8 upgradeCounter;
        (,,,upgradeCounter) = IHRSYToken(address(HRSYToken)).horseys(tokenId);
        require(upgradeCounter > 0,"Basic HRSY aren't tradable");
        //Transfers token from depositee to exchange (contract address)
        HRSYToken.transferFrom(msg.sender, address(this), tokenId);
        
        //add the token to the market
        market[tokenId] = SaleData(price,msg.sender);

        //Add token to exchange map - tracking by owner of all tokens
        userBarn[msg.sender].push(tokenId);

        emit HorseyDeposit(tokenId, price);
    }

    /**
        @dev Allows true owner of token to cancel sale at anytime
        @param tokenId ID of the token to remove from the market
        @return true if user still has tokens for sale
    */
    function cancelSale(uint256 tokenId) external 
    whenNotPaused()
    originalOwnerOf(tokenId) 
    returns (bool) {
        //throws on fail - transfers token from exchange back to original owner
        HRSYToken.transferFrom(address(this),msg.sender,tokenId);
        
        //Reset token on market - remove
        delete market[tokenId];

        //Reset barn tracker for user
        _removeTokenFromBarn(tokenId, msg.sender);

        emit SaleCanceled(tokenId);

        //Return true if this user is still 'active' within the exchange
        //This will help with client side actions
        return userBarn[msg.sender].length > 0;
    }

    /**
        @dev Performs the purchase of a token that is present on the market - this includes checking that the
            proper amount is sent + applied fee, updating seller's balance, updated collected fees and
            transfering token to buyer
            Only market tokens can be purchased
        @param tokenId ID of the token we wish to purchase
    */
    function purchaseToken(uint256 tokenId) external 
    whenNotPaused()
    isOnMarket(tokenId) 
    notOriginalOwnerOf(tokenId)
    {
        uint256 totalToPay = getTokenPrice(tokenId);
        require(_wallet.balanceOf(msg.sender) >= totalToPay,"Insufficient HORSE funds!");

        //fetch this tokens sale data
        SaleData memory sale = market[tokenId];

        //Add to collected fee amount payable to DEVS
        uint256 collectedFees = totalToPay - sale.price;
        uint256 devFees = collectedFees / 100 * devEquity;
        //pay the seller
        _wallet.transferFromAndTo(msg.sender,sale.owner,sale.price);
        //pay the market fee to pool
        _wallet.transferFromAndTo(msg.sender,address(_wallet),collectedFees-devFees);
        //pay the devs
        _wallet.transferFromAndTo(msg.sender,address(this),devFees);

        //Reset barn tracker for user
        _removeTokenFromBarn(tokenId,  sale.owner);

        //Reset token on market - remove
        delete market[tokenId];

        //Transfer the ERC721 to the buyer - we leave the sale amount
        //to be withdrawn by the user (transferred from exchange)
        HRSYToken.transferFrom(address(this), msg.sender, tokenId);

        emit HorseyPurchased(tokenId, msg.sender, totalToPay);
    }

    /**
        @dev Owner can withdraw the current HORSE balance
    */
    function withdraw() external 
    onlyOwner()  {
        uint256 balance = _wallet.balanceOf(address(this));
        if(balance > 0) {
            _wallet.withdraw(balance); //get all the HORSE we earned from the wallet
            //send them to our owner
            _horseToken.transfer(owner(),balance);
        }
    }

    /**
        @dev Internal function to remove a token from the users barn array
        @param tokenId ID of the token to remove
        @param barnAddress Address of the user selling tokens
    */
    function _removeTokenFromBarn(uint tokenId, address barnAddress)  internal {
        uint256[] storage barnArray = userBarn[barnAddress];
        require(barnArray.length > 0,"No tokens to remove");
        int index = _indexOf(tokenId, barnArray);
        require(index >= 0, "Token not found in barn");

        // Shift entire array :(
        for (uint256 i = uint256(index); i<barnArray.length-1; i++){
            barnArray[i] = barnArray[i+1];
        }

        // Remove element, update length, return array
        // this should be enough since https://ethereum.stackexchange.com/questions/1527/how-to-delete-an-element-at-a-certain-index-in-an-array
        barnArray.length--;
    }

    /**
        @dev Helper function which stores in memory an array which is passed in, and
        @param item element we are looking for
        @param array the array to look into
        @return the index of the item of interest
    */
    function _indexOf(uint item, uint256[] memory array) internal pure returns (int256){

        //Iterate over array to find indexOf(token)
        for(uint256 i = 0; i < array.length; i++){
            if(array[i] == item){
                return int256(i);
            }
        }

        //Item not found
        return -1;
    }

    /// @dev requires token to be on the market = current owner is exchange
    modifier isOnMarket(uint256 tokenId) {
        require(HRSYToken.ownerOf(tokenId) == address(this),"Token not on market");
        _;
    }
    
    /// @dev Is the user the owner of this token?
    modifier isTokenOwner(uint256 tokenId) {
        require(HRSYToken.ownerOf(tokenId) == msg.sender,"Not tokens owner");
        _;
    }

    /// @dev Is this the original owner of the token - at exchange level
    modifier originalOwnerOf(uint256 tokenId) {
        require(market[tokenId].owner == msg.sender,"Not the original owner of");
        _;
    }

    /// @dev Is this the original owner of the token - at exchange level
    modifier notOriginalOwnerOf(uint256 tokenId) {
        require(market[tokenId].owner != msg.sender,"Is the original owner");
        _;
    }

    /// @dev Is a nonzero price being sent?
    modifier nonZeroPrice(uint256 price){
        require(price > 0,"Price is zero");
        _;
    }
}