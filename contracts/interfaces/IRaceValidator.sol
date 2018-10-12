pragma solidity ^0.4.24;

/**
    @title API contract - used to connect with Race contract and 
        encapsulate race information for token inidices and winner
        checking.
*/
interface IRaceValidator {
    /**
        @param raceAddress - address of this race
        @param eth_address - user's ethereum wallet address
        @return (bool won, bytes32 winner_horse, uint256 betAmount, uint256 totalBetAmount)
    */
    function validateWinner(address raceAddress, address eth_address) external view returns (bool,bytes32,uint256,uint256);
    /**
        @dev Function called by a contract to fetch this race starting time
        @param raceAddress - address of this race
        @return Timestamp of when the race started or will start
    */
    function getRaceTime(address raceAddress) external view returns (uint32);
}