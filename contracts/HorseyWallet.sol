pragma solidity ^0.4.24;

import "../openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "../openzeppelin-solidity/contracts/ownership/Ownable.sol";

/**
    @title HorseyWallet
    @dev A wallet with special authorizations for the game contracts to withdraw and fund balances
    The player must store HORSE here in order to play
*/
contract HorseyWallet is Ownable {
    /// @dev Triggered when a user deposits HORSE to this contract
    event Deposit(address indexed from, uint256 amount);
    /// @dev Triggered when a user takes his HORSE from this wallets credit
    event Withdrawal(address indexed from, uint256 amount);
    /// @dev Triggered when a spender withdraws the tokens it needs
    event Payment(address indexed from, address indexed to, uint256 amount);

    /// @dev horse token access interface
    IERC20 public horseToken;

    /// @dev map of approved addresses to use user balance from this wallet
    mapping(address => bool) public approvedSpenders;

    /// @dev Balances in horse owned by users
    mapping(address => uint256) public balanceOf;

    /// @dev Balances in HXP owned by users
    mapping(address => uint256) public balanceOfHXP;

    constructor(address HORSETokenAddress) Ownable() public {
        if(HORSETokenAddress == address(0)) {
            horseToken = IERC20(0x5B0751713b2527d7f002c0c4e2a37e1219610A6B);
        } else {
            horseToken = IERC20(HORSETokenAddress);
        }
    }

    /**
        @dev Used to add funds (like a HORSE donation)
            Funds are stored in balanceOf[address(this)]
        @param amount Amount of HORSE to add to the funds account
    */
    function addFunds(uint256 amount) external {
         //transfer HORSE to self
        require(horseToken.transferFrom(msg.sender,address(this),amount),"Token transfer failed");
        balanceOf[address(this)] = balanceOf[address(this)] + amount;
    }

    /**
        @dev Transfer HORSE to this wallets balance
        @param amount Amount of HORSE to transfer from user to this wallet
    */
    function deposit(uint256 amount) external {
        //credit horse to this balance
        require(horseToken.transferFrom(msg.sender,address(this),amount),"Token transfer failed");
        balanceOf[msg.sender] = balanceOf[msg.sender] + amount;
        emit Deposit(msg.sender,amount);
    }

    /**
        @dev Transfer HORSE from the wallet to the user
        @param amount Amount of HORSE to withdraw from this wallet
    */
    function withdraw(uint256 amount) external
    holdsEnough(msg.sender,amount) {
        //try to send to this user the amount he owns
        require(horseToken.transfer(msg.sender,amount),"Token transfer failed");
        balanceOf[msg.sender] = balanceOf[msg.sender] - amount;
        emit Withdrawal(msg.sender,amount);
    }

    /**
        @dev Transfer HORSE from the wallets' pool to the devs
        @param amount Amount of HORSE to withdraw from this wallets' pool
    */
    function withdrawPool(uint256 amount) external
    holdsEnough(address(this),amount)
    isSpender(msg.sender) {
        require(horseToken.transfer(msg.sender,amount),"Token transfer failed");
        balanceOf[address(this)] = balanceOf[address(this)] - amount;
    }

    /**
        @dev Allows an approved spender to withdraw any amount of HORSE from any user!!!
        @param account_from Account to transfer HORSE from
        @param account_to Account to transfer HORSE to
        @param amount Amount of HORSE to transfer
     */
    function transferFromAndTo(address account_from, address account_to, uint256 amount) external
    holdsEnough(account_from,amount)
    isSpender(msg.sender) {
        require(account_from != account_to,"Source and destination bust be different!");
        balanceOf[account_to] = balanceOf[account_to] + amount;
        balanceOf[account_from] = balanceOf[account_from] - amount;
        emit Payment(account_from,account_to,amount);
    }

    /**
        @dev Used to add HXP
            Funds are stored in balanceOfHXP[address(this)]
        @param amount Amount of HXP to add to the funds account
    */
    function creditHXP(address account, uint256 amount) external
    isSpender(msg.sender) {
        balanceOfHXP[account] = balanceOfHXP[account] + amount;
    }

    /**
        @dev Used to add HXP
            Funds are stored in balanceOfHXP[address(this)]
        @param amount Amount of HXP to add to the funds account
    */
    function spendHXP(address account, uint256 amount) external
    isSpender(msg.sender) {
        require(balanceOfHXP[account] >= amount,"Insufficient HXP funds");
        balanceOfHXP[account] = balanceOfHXP[account] - amount;
    }

    /**
        @dev Allows the owner to add addresses which can withdraw from this contract without validation
        @param spender The address of an allowed spender
    */
    function addApprovedSpender(address spender) external
    onlyOwner()
    validAddress(spender) {
        approvedSpenders[spender] = true;
    }

    /**
        @dev Disallows the owner to add addresses which can withdraw from this contract without validation
        @param spender The address of an allowed spender
    */
    function removeApprovedSpender(address spender) external
    onlyOwner()
    isSpender(spender) {
        approvedSpenders[spender] = false;
    }

    /** @dev makes sure the account owns enough HORSE to withdraw this amount
        @param account ERC20 holder account
        @param amount Amount of HORSE
    */
    modifier holdsEnough(address account, uint256 amount) {
        require(balanceOf[account] >= amount,"Insufficient HORSE funds");
        _;
    }

    modifier isSpender(address account) {
        require(approvedSpenders[account],"Not approved spender!");
        _;
    }

    /// @dev requires the address to be non null
    modifier validAddress(address addr) {
        require(addr != address(0),"Address must be non zero");
        _;
    }
}