pragma solidity ^0.4.24;

contract BettingTest {
    mapping(address => mapping(bytes32 => uint256)) bets;

    // place a bet on a coin(horse) lockBetting
    function placeBet(bytes32 horse) external payable {
        bets[msg.sender][horse] += msg.value;
    }
    function checkReward() external constant returns (uint) {
        return bets[msg.sender][bytes32("BTC")];
    }
    // method to claim the reward amount
    function claim_reward() external {
        msg.sender.transfer(bets[msg.sender][bytes32("BTC")]);
    }
    
    constructor() public {
        winner_horse[bytes32("BTC")] = true;
    }
    
    mapping (bytes32 => bool) public winner_horse;
    
    
}