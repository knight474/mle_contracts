pragma solidity ^0.4.24;

import "../openzeppelin-solidity/contracts/math/SafeMath.sol";

contract EthorsePassive {
    using SafeMath for uint256;    
    
    event Deposit(address user, uint256 amount);
    event Paused(address user);
    event Unpaused(address user);
    
    struct Settings {
        uint256 maxBet;
        //The 3 combined should equal to 1000 (ratio based)
        uint16 betOnBTC;
        uint16 betOnLTC;
        uint16 betOnETH;
        uint8 racesPerDay;
        bool paused;
    }
    
    mapping(address => uint256) pools;
    mapping(bytes32 => uint256) common_pools;
    mapping(address => Settings) settings;
    
    uint256 toDistribute;

    constructor() public {
        
    }
    
    function deposit() external payable {
        //3%
        uint256 depositFee = msg.value / 100 * 3;
        toDistribute = toDistribute.add(depositFee);
        uint256 toDeposit = msg.value.sub(depositFee);
        //store the rest
        pools[msg.sender] = pools[msg.sender].add(toDeposit);
        
        emit Deposit(msg.sender,toDeposit);
    }
    
    function pause() external {
        settings[msg.sender].paused = true;
        emit Paused(msg.sender);
    }
    
    function configure(uint256 maxBet, uint16 betOnLTC, uint16 betOnBTC, uint16 betOnETH, uint8 racesPerDay) external {
        require(maxBet >= 0.01 ether, "Minimal bet on Ethorse is 0.01 eth");
        require((betOnLTC + betOnBTC + betOnETH) == 1000, "The sum of the ratio on the 3 coins must equal to 1"); //1000
        require(racesPerDay >= 1, "At least one race a day");
        require(pools[msg.sender] >= maxBet,"You dont have enough in your betting pool");
        
        Settings storage config = settings[msg.sender];
        config.maxBet = maxBet;
        config.betOnLTC = betOnLTC;
        config.betOnBTC = betOnBTC;
        config.betOnETH = betOnETH;
        config.racesPerDay = racesPerDay;
        config.paused = false;

        common_pools["BTC"] = pools[msg.sender]
        
        emit Unpaused(msg.sender);
    }
    
    function autobet(address race) external {
        
    }
}
