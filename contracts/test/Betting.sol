pragma solidity ^0.4.23;

/**
    Race contract - used for linking ethorse Race struct 
**/
contract Betting {

    //Encapsulation of racing information 
    struct chronus_info {
        bool  betting_open; // boolean: check if betting is open
        bool  race_start; //boolean: check if race has started
        bool  race_end; //boolean: check if race has ended
        bool  voided_bet; //boolean: check if race has been voided
        uint32  starting_time; // timestamp of when the race starts
        uint32  betting_duration;
        uint32  race_duration; // duration of the race
        uint32 voided_timestamp;
    }

    struct bet {
        mapping(bytes32 => uint) bets;
    }
    
    //Point to racing information
    chronus_info public chronus;

    address public owner;

    //Coin index mapping to flag - true if index is winner
    mapping (bytes32 => bool) public winner_horse;

    mapping (address => bet) internal bets;

    // method to claim the reward amount
    function claim_reward() external {
        uint value = 0;
        if(winner_horse["ETH"])
            value = bets[msg.sender].bets["ETH"];
        if(winner_horse["BTC"])
            value = bets[msg.sender].bets["BTC"];
        if(winner_horse["LTC"])
            value = bets[msg.sender].bets["LTC"];
        require(value > 0);
        msg.sender.transfer(value);
    }
    
    function checkReward() external constant returns (uint) {
        if(winner_horse["ETH"])
            return bets[msg.sender].bets["ETH"];
        if(winner_horse["BTC"])
            return bets[msg.sender].bets["BTC"];
        if(winner_horse["LTC"])
            return bets[msg.sender].bets["LTC"];
    }

    constructor() public {
        chronus.betting_open = false;
        chronus.race_start = true;
        chronus.race_end = false;
        chronus.voided_bet = false;
        owner = msg.sender;
    }

    function setEnded(bytes32 winnerHorse) external {
        chronus.betting_open = false;
        chronus.race_start = true;
        chronus.race_end = true;
        chronus.voided_bet = false;

        winner_horse[winnerHorse] = true;
    }

    function setVoided(bool voided) external {
        chronus.voided_bet = voided;
    }

    function addBet(bytes32 horse, uint amount) external {
        bets[msg.sender].bets[horse] = bets[msg.sender].bets[horse] + amount;
    }

    function placeBet(bytes32 horse) external payable {
        bets[msg.sender].bets[horse] += msg.value;
    }

    // exposing the coin pool details for DApp
    function getCoinIndex(bytes32 index, address candidate) external constant returns (uint, uint, uint, bool, uint) 
    {
        return (0,0,0,true,bets[candidate].bets[index]);
    }
}