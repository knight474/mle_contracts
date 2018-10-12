pragma solidity ^0.4.24;

import "../openzeppelin-solidity/contracts/ownership/Ownable.sol";

/**
    @title Race contract - used for linking ethorse Race struct 
    @dev This interface is losely based on ethorse race contract
*/
interface EthorseRace {
    function owner() external view returns (address);
    function chronus() external view returns (
        bool betting_open, 
        bool race_start, 
        bool race_end, 
        bool voided_bet, 
        uint32 starting_time,
        uint32  betting_duration,
        uint32  race_duration,
        uint32 voided_timestamp
        );
    function winner_horse(bytes32 horse) external view returns (bool);
    function getCoinIndex(bytes32 index, address candidate) external view returns (
        uint total, 
        uint pre, 
        uint post, 
        bool price_check, 
        uint betAmount);
}

/**
    @title API contract - used to connect with Race contract and 
        encapsulate race information for token inidices and winner
        checking.
*/
contract RaceValidator is Ownable {

    /// @dev Convert all symbols to bytes array
    bytes32[] public all_horses = [bytes32("BTC"),bytes32("ETH"),bytes32("LTC")];
    /// @dev list of races known to be legit (published by ethorse)
    mapping(address => bool) public legitRaces;
    /// @dev flag set to true if only legit races can be valid
    bool onlyLegit = false;

    constructor() public 
    Ownable() {

    }

    /**
        @dev Adds a new race to the legit races list
        @param newRace Contract ID of the race
    */
    function addLegitRace(address newRace) external
    validAddress(newRace)
    onlyOwner()
    {
        legitRaces[newRace] = true;
        // automatically set the flag to true
        if(!onlyLegit)
            onlyLegit = true;
    }

    /**
        @dev Function called by a contract to fetch this race starting time
        @param raceAddress - address of this race
        @return Timestamp of when the race started or will start
    */
    function getRaceTime(address raceAddress) external view returns (uint32) {
        EthorseRace race = EthorseRace(raceAddress);
        uint32 startingTime;
        (,,,,startingTime,,,) = race.chronus();
        return startingTime;
    }

    /**
        @dev Function called by a contract to validate if eth_address is a winner of the ethorse race at raceAddress
        @param raceAddress - address of this race
        @param eth_address - user's ethereum wallet address
        @return true if user is winner + name of the winning horse (LTC,BTC,ETH,...)
    */
    function validateWinner(address raceAddress, address eth_address) external view 
    returns (bool,bytes32,uint256,uint256)
    {
        EthorseRace race = EthorseRace(raceAddress);
       
        //make sure the race is legit (only if legit races list is filled)
        if(onlyLegit)
            require(legitRaces[raceAddress],"not legit race");
        //acquire chronus
        bool  voided_bet; //boolean: check if race has been voided
        bool  race_end; //boolean: check if race has ended
        (,,race_end,voided_bet,,,,) = race.chronus();

        //cant be winner if race was refunded or didnt end yet
        if(voided_bet || !race_end)
            return (false,bytes32(0),0,0);

        //Iterate over coin symbols to find winner - tie could be possible
        uint256 totalBetAmount = 0;
        bytes32 winner = bytes32(0);
        uint256 winnerBetAmount = 0;
        for(uint256 i = 0; i < all_horses.length; i++)
        {
            if(race.winner_horse(all_horses[i])) {
                //check the bet amount of the eth_address on the winner horse
                uint256 bet_amount = 0;
                (,,,, bet_amount) = race.getCoinIndex(all_horses[i], eth_address);
                if(bet_amount > 0) {
                    winner = all_horses[i];
                    totalBetAmount = totalBetAmount + bet_amount;
                    winnerBetAmount = bet_amount;
                }
            }
        }
        return (winner != bytes32(0),winner,winnerBetAmount, totalBetAmount);
    }

    /// @dev requires the address to be non null
    modifier validAddress(address addr) {
        require(addr != address(0),"Address must be non zero");
        _;
    }
}