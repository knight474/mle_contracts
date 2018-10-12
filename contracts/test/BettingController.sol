pragma solidity ^0.4.24;

import "./Betting.sol";

contract BettingController {
    address public owner;
    address public race;

    constructor() public {
        owner = msg.sender;

        race = new Betting();
    }
}