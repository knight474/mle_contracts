pragma solidity ^0.4.24;

import "./interfaces/IHorseyGame.sol";
import "./interfaces/IHorseyExchange.sol";
import "./interfaces/IHorseyWallet.sol";
import "./interfaces/IRaceValidator.sol";
import "./interfaces/IHRSYToken.sol";
import "../openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

/**
    @title Adds rank management utilities and voting behavior
    @dev Handles equities distribution and levels of access
*/

contract HorseyPilot {

    /// @dev event that is fired when a new proposal is made
    event NewProposal(uint8 methodId, uint parameter, address proposer);

    /// @dev event that is fired when a proposal is accepted
    event ProposalPassed(uint8 methodId, bytes32 parameterName, uint parameter, address proposer);

    /// @dev minimum threshold that must be met in order to confirm
    /// a contract update
    uint8 constant votingThreshold = 2;

    /// @dev minimum amount of time a proposal can live
    /// after this time it can be forcefully invoked or killed by anyone
    uint256 constant proposalLife = 7 days;

    /// @dev amount of time until another proposal can be made
    /// we use this to eliminate proposal spamming
    uint256 constant proposalCooldown = 1 days;

    /// @dev used to reference the exact time the last proposal vetoed
    uint256 cooldownStart;

    /// @dev The addresses of the accounts (or contracts) that can execute actions within each roles.
    address public jokerAddress;
    address public knightAddress;
    address public paladinAddress;

    /// @dev List of all addresses allowed to vote
    address[3] public voters;

    /// @dev joker is the pool and gets the rest
    uint8 constant public knightEquity = 40;
    uint8 constant public paladinEquity = 10;

    /// @dev deployed exchange, wallet and token addresses
    IHorseyExchange public exchange;
    IHRSYToken public token;
    IHorseyWallet public wallet;
    IRaceValidator public validator;
    IHorseyGame public game;

    /// @dev Mapping to keep track of pending balance of contract owners
    mapping(address => uint) internal _cBalance;

    /// @dev Encapsulates information about a proposed update
    struct Proposal{
        address proposer;           /// @dev address of the CEO at the origin of this proposal
        uint256 timestamp;          /// @dev the time at which this propsal was made
        bytes32 parameterName;       /// @dev in case we change the config value this must be named
        uint256 parameter;          /// @dev parameters associated with proposed method invocation
        uint8   methodId;           /// @dev id maps to function 0:rename horse, 1:change fees, 2:?    
        address[] yay;              /// @dev list of all addresses who voted     
        address[] nay;              /// @dev list of all addresses who voted against     
    }

    /// @dev the pending proposal
    Proposal public currentProposal;

    /// @dev true if the proposal is waiting for votes
    bool public proposalInProgress = false;

    /// @dev Value to keep track of avaible balance
    uint256 public toBeDistributed;

    /// @dev horse token access interface
    IERC20 public HORSEToken;

    /**
        @param _jokerAddress joker
        @param _knightAddress knight
        @param _paladinAddress paladin
        @param _voters list of all allowed voting addresses
    */
    constructor(
    address _jokerAddress,
    address _knightAddress,
    address _paladinAddress,
    address[3] _voters
    ) public {
        jokerAddress = _jokerAddress;
        knightAddress = _knightAddress;
        paladinAddress = _paladinAddress;

        for(uint i = 0; i < 3; i++) {
            voters[i] = _voters[i];
        }

        //Set cooldown start to 1 day ago so that cooldown is irrelevant
        cooldownStart = block.timestamp - proposalCooldown;

        HORSEToken = IERC20(0x5B0751713b2527d7f002c0c4e2a37e1219610A6B);
    }

    /**
        @dev Used to deploy children contracts as a one shot call
    */
    function setupContracts(
        address tokenAddress,
        address walletAddress,
        address exchangeAddress,
        address validatorAddress,
        address gameAddress) external 
        validAddress(tokenAddress) 
        validAddress(walletAddress) 
        validAddress(exchangeAddress) 
        validAddress(validatorAddress) 
        validAddress(gameAddress) {
        // deploy contracts
        token = IHRSYToken(tokenAddress);
        wallet = IHorseyWallet(walletAddress);
        exchange = IHorseyExchange(exchangeAddress);
        validator = IRaceValidator(validatorAddress);
        game = IHorseyGame(gameAddress);

        require(token.owner() == address(this),"Pilot must be owner of token contract");
        require(wallet.owner() == address(this),"Pilot must be owner of wallet contract");
        require(exchange.owner() == address(this),"Pilot must be owner of exchange contract");
        require(game.owner() == address(this),"Pilot must be owner of game contract");
    }

    /**
        @dev Transfers joker ownership to a new address
        @param newJoker the new address
    */
    function transferJokerOwnership(address newJoker) external 
    validAddress(newJoker) {
        require(jokerAddress == msg.sender,"Not right role");
        _moveBalance(newJoker);
        jokerAddress = newJoker;
    }

    /**
        @dev Transfers knight ownership to a new address
        @param newKnight the new address
    */
    function transferKnightOwnership(address newKnight) external 
    validAddress(newKnight) {
        require(knightAddress == msg.sender,"Not right role");
        _moveBalance(newKnight);
        knightAddress = newKnight;
    }

    /**
        @dev Transfers paladin ownership to a new address
        @param newPaladin the new address
    */
    function transferPaladinOwnership(address newPaladin) external 
    validAddress(newPaladin) {
        require(paladinAddress == msg.sender,"Not right role");
        _moveBalance(newPaladin);
        paladinAddress = newPaladin;
    }

    /**
        @dev Allow CEO to withdraw from pending value always checks to update redist
            We ONLY redist when a user tries to withdraw so we are not redistributing
            on every payment
        @param destination The address to send the ether to
    */
    function withdrawCeo(address destination) external 
    onlyCLevelAccess()
    validAddress(destination) {
        //Check that pending balance can be redistributed - if so perform
        //this procedure
        if(toBeDistributed > 0){
            _updateDistribution();
        }
        
        //Grab the balance of this CEO 
        uint256 balance = _cBalance[msg.sender];
        
        //If we have non-zero balance, CEO may withdraw from pending amount
        if(balance > 0) {
            require(HORSEToken.transfer(msg.sender,balance),"Failed to transfer HORSE token");
            _cBalance[msg.sender] = 0;
        }
    }

    /// @dev acquire funds from owned contracts
    function syncFunds() external {
        uint256 prevBalance = HORSEToken.balanceOf(address(this));
        game.withdraw();
        exchange.withdraw();
        uint256 newBalance = HORSEToken.balanceOf(address(this));
        //add to
        toBeDistributed = toBeDistributed + (newBalance - prevBalance);
    }

    /// @dev allows a noble to access his holdings
    function getNobleBalance() external view
    onlyCLevelAccess() returns (uint256) {
        return _cBalance[msg.sender];
    }

    /**
        @dev Make a proposal and add to pending proposals
        @param methodId a string representing the function ie. 'renameHorsey()'
        @param parameterName in case we change a config value (methodId == 0) this is required, can be set to 0 for other methods
        @param parameter parameter to be used if invocation is approved
    */
    function makeProposal( uint8 methodId, bytes32 parameterName, uint256 parameter ) external
    onlyCLevelAccess()
    proposalAvailable()
    cooledDown()
    {
        currentProposal.timestamp = block.timestamp;
        currentProposal.parameterName = parameterName;
        currentProposal.parameter = parameter;
        currentProposal.methodId = methodId;
        currentProposal.proposer = msg.sender;
        delete currentProposal.yay;
        delete currentProposal.nay;
        proposalInProgress = true;
        
        emit NewProposal(methodId,parameter,msg.sender);
    }

    /**
        @dev Call to vote on a pending proposal
    */
    function voteOnProposal(bool voteFor) external 
    proposalPending()
    onlyVoters()
    notVoted() {
        //cant vote on expired!
        require((block.timestamp - currentProposal.timestamp) <= proposalLife);
        if(voteFor)
        {
            currentProposal.yay.push(msg.sender);
            //Proposal went through? invoke it
            if( currentProposal.yay.length >= votingThreshold )
            {
                _doProposal();
                proposalInProgress = false;
                //no need to reset cooldown on successful proposal
                return;
            }

        } else {
            currentProposal.nay.push(msg.sender);
            //Proposal failed?
            if( currentProposal.nay.length >= votingThreshold )
            {
                proposalInProgress = false;
                cooldownStart = block.timestamp;
                return;
            }
        }
    }

    /**
        @dev Helps moving pending balance from one role to another
        @param newAddress the address to transfer the pending balance from the msg.sender account
    */
    function _moveBalance(address newAddress) internal
    validAddress(newAddress) {
        require(newAddress != msg.sender,"Cant move to self!"); /// @dev IMPORTANT or else the account balance gets reset here!
        _cBalance[newAddress] = _cBalance[msg.sender];
        _cBalance[msg.sender] = 0;
    }

    /**
        @dev Called at the start of withdraw to distribute any pending balances that live in the contract
            will only ever be called if balance is non-zero (funds should be distributed)
    */
    function _updateDistribution() internal {
        require(toBeDistributed != 0,"nothing to distribute");
        uint256 knightPayday = toBeDistributed / 100 * knightEquity;
        uint256 paladinPayday = toBeDistributed / 100 * paladinEquity;

        /// @dev due to the equities distribution, queen gets the remaining value
        uint256 jokerPayday = toBeDistributed - knightPayday - paladinPayday;

        _cBalance[jokerAddress] = _cBalance[jokerAddress] + jokerPayday;
        _cBalance[knightAddress] = _cBalance[knightAddress] + knightPayday;
        _cBalance[paladinAddress] = _cBalance[paladinAddress] + paladinPayday;
        //Reset balance to 0
        toBeDistributed = 0;
    }

    /**
        @dev Execute the proposal
    */
    function _doProposal() internal {
        if( currentProposal.methodId == 0 ) game.setConfigValue(currentProposal.parameterName,currentProposal.parameter);

        /// UPDATE validator address
        if( currentProposal.methodId == 1 ) game.setValidator(address(currentProposal.parameter));

        /// UPDATE the market fees
        if( currentProposal.methodId == 2 ) exchange.setMarketFees(currentProposal.parameter);

        /// UPDATE the market fees
        if( currentProposal.methodId == 3 ) exchange.setDevEquity(currentProposal.parameter);

        /// UPDATE the market fees
        if( currentProposal.methodId == 4 ) exchange.setCreatorEquity(currentProposal.parameter);

        /// ADD the approved spender for wallet (should be current game address and current market address)
        if( currentProposal.methodId == 5 ) wallet.addApprovedSpender(address(currentProposal.parameter));

        /// DELETE a specific spender from the approved list
        if( currentProposal.methodId == 6 ) wallet.removeApprovedSpender(address(currentProposal.parameter));

        /// UPDATE the current master of the HRSY token (allowed to change any value on the HRSY token contract at will!!! Should be the current game address)
        if( currentProposal.methodId == 7 ) token.changeMaster(address(currentProposal.parameter));

        /// PAUSE/UNPAUSE the main contracts
        if( currentProposal.methodId == 8 ) {
            if(currentProposal.parameter == 0) {
                exchange.unpause();
                token.unpause();
            } else {
                exchange.pause();
                token.pause();
            }
        }

        emit ProposalPassed(currentProposal.methodId,currentProposal.parameterName,currentProposal.parameter,currentProposal.proposer);
    }

    /// @dev requires the address to be non null
    modifier validAddress(address addr) {
        require(addr != address(0),"Address is zero");
        _;
    }

    /// @dev requires the sender to be on the contract owners list
    modifier onlyCLevelAccess() {
        require((jokerAddress == msg.sender) || (knightAddress == msg.sender) || (paladinAddress == msg.sender),"not c level");
        _;
    }

    /// @dev requires that a proposal is not in process or has exceeded its lifetime, and has cooled down
    /// after being vetoed
    modifier proposalAvailable(){
        require(((!proposalInProgress) || ((block.timestamp - currentProposal.timestamp) > proposalLife)),"proposal already pending");
        _;
    }

    // @dev requries that if this proposer was the last proposer, that he or she has reached the 
    // cooldown limit
    modifier cooledDown( ){
        if(msg.sender == currentProposal.proposer && (block.timestamp - cooldownStart < 1 days)){
            revert("Cool down period not passed yet");
        }
        _;
    }

    /// @dev requires a proposal to be active
    modifier proposalPending() {
        require(proposalInProgress,"no proposal pending");
        _;
    }

    /// @dev requires the voter to not have voted already
    modifier notVoted() {
        uint256 length = currentProposal.yay.length;
        for(uint i = 0; i < length; i++) {
            if(currentProposal.yay[i] == msg.sender) {
                revert("Already voted");
            }
        }

        length = currentProposal.nay.length;
        for(i = 0; i < length; i++) {
            if(currentProposal.nay[i] == msg.sender) {
                revert("Already voted");
            }
        }
        _;
    }

    /// @dev requires the voter to not have voted already
    modifier onlyVoters() {
        bool found = false;
        uint256 length = voters.length;
        for(uint i = 0; i < length; i++) {
            if(voters[i] == msg.sender) {
                found = true;
                break;
            }
        }
        if(!found) {
            revert("not a voter");
        }
        _;
    }
}