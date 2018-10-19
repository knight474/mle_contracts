pragma solidity ^0.4.24;

import "./interfaces/IHRSYToken.sol";
import "./interfaces/IRaceValidator.sol";
import "./WalletUser.sol";
import "../openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "../openzeppelin-solidity/contracts/ownership/Ownable.sol";

/**
    @title HorseyToken ERC721 Token
    @dev Horse contract - horse derives from Pausable
*/
contract HorseyGame is WalletUser, Pausable, Ownable {
    /// @dev called when someone claims his HORSE from a RWRD HRSY
    event RewardClaimed(uint256 tokenId, address to, uint256 Amount);

    /// @dev called when someone claims a token
    event Claimed(address raceAddress, address eth_address, uint256 tokenId);

    /// @dev called when someone ends a feeding process
    event Upgraded(uint256 tokenId);

    /// @dev called when a horsey is renamed
    event Renamed(uint256 tokenId, string newName);

    /// @dev called when a horsey is burned
    event Burned(uint256 tokenId);

    /// @dev called when someone purchases HXP using HORSE
    event HXPPurchased(address account, uint256 amount);

    /// @dev address of the HRSYToken
    IHRSYToken public HRSYToken;

    /// @dev race winner validation access interface
    IRaceValidator public validator;

    /// @dev Maps the values table for upgrading, burning, etc
    mapping(bytes32 => uint256) public config;

    /// @dev Maps a user to his wins count, used for claiming with RWRD HRSY
    mapping(address => uint16) public wins;

    /// @dev Maps an HRSY id to the wins counter value when last claimed reward
    mapping(uint256 => uint16) public rewarded;

    /// @dev Devs cut is the amount of HORSE earned by devs through their equity
    uint256 devCut;

    /**
        @dev Contracts constructor
            Initializes token data
            is pausable,ownable
        @param tokenAddress Address of the official HRSYToken contract
        @param validatorAddress Address of the current contract used for race validation
        @param walletAddress Address of the current wallet contract
    */
    constructor(address tokenAddress, address validatorAddress, address walletAddress) 
    WalletUser(walletAddress)
    Pausable()
    Ownable() public {
        require(validatorAddress != address(0) && tokenAddress != address(0),"Invalid addresses");

        HRSYToken = IHRSYToken(tokenAddress);
        validator = IRaceValidator(validatorAddress);
        //setting default values

        //%
        config["CONVRATE"] = 3;
        config["CONVFEE"] = 9;
        config["DEVEQ1"] = 10; //10% for the devs from the CONVFEE
        config["DEVEQ2"] = 20; //20% for the devs from operation fees

        config["CREATOREQ"] = 20; //20% HORSE goes to the RWRD HRSY creator

        //HORSE
        //Amount of HORSE required to claim and rename a token
        config["CLAIMFEE"] = 10 ether;
        config["RENAMEFEE"] = 5 ether;

        //Amount of HORSE sent to the player FOR EACH Reward HRSY when he wins
        //depends on the HRSY lvl (minimum lvl 3 required for RWRD0)
        config["RWRD0"] = 500 ether;
        config["RWRD1"] = 1500 ether;
        config["RWRD2"] = 3000 ether;

        //Amount of HORSE required to burn a normal and a rare HRSY
        config["BURNFEE0"] = 2 ether;
        config["BURNFEE1"] = 10 ether;

        //Amount of HORSE required to lvl up an HRSY
        config["UPGRFEE"] = 50 ether;

        //HXP
        //Burning rewards in HXP for a normal and a rare HRSY
        config["BURN0"] = 1000;
        config["BURN1"] = 5000;
        //Allows to multiply the reward for burning based on the bet amount.
        //BURNMULT is a /100 ratio
        config["BURNMULT"] = 100;
        config["MINBET"] = 0.01 ether;
        config["MAXBET"] = 1 ether;
        //minimum bet multiplier 
        config["BETMULT"] = 200;
        
        //Upgrade costs in HXP for all lvls
        config["UPGR0"] = 5000;
        config["UPGR1"] = 200000;
        config["UPGR2"] = 800000;
        config["UPGR3"] = 1200000;

        //begin and start timestamps of bonus period
        config["BPERIODBEGIN"] = 1538517600; //  October 3th 2018
        config["BPERIODEND"] = 1543618800; //  December 1st 2018

        //bonus period multiplier in %
        config["BONUSMULT"] = 200;
    }

    /**
        @dev Change wallet address
        @param validatorAddress the new address
    */
    function setValidator(address validatorAddress) external
    validAddress(validatorAddress)
    onlyOwner() {
        validator = IRaceValidator(validatorAddress);
    }

    /**
        @dev Changes the amount of horse required to upgrade a horsey
        @param name Name of the value to change
        @param newValue The new value
    */
    function setConfigValue(bytes32 name, uint256 newValue) external 
    onlyOwner()  {
        config[name] = newValue;
    }

    /**
        @dev Owner can withdraw the current HORSE balance
    */
    function withdraw() external 
    onlyOwner()  {
        if(devCut > 0) {
            _wallet.withdrawPool(devCut); //get all the HORSE we earned from the wallet
            //send them to our owner
            _horseToken.transfer(owner(),devCut);
            devCut = 0;
        }
    }

    /**
        @dev Returns horsey data of a given token
        @param tokenId ID of the horsey to fetch
        @return (race address, dna, upgradeCounter, name)
    */
    function getHorsey(uint256 tokenId) public view returns (address, bytes32, uint8, string, uint32) {
        bytes32 dna;
        address race;
        uint32 betAmountFinney;
        uint8 upgradeCounter;
        (dna, race, betAmountFinney, upgradeCounter) = HRSYToken.horseys(tokenId);
        return (race,dna,upgradeCounter,HRSYToken.names(tokenId),betAmountFinney);
    }

    /**
        @dev Claiming HORSE from a reward HRSY
        @param tokenId ID of the RWRD HRSY
    */
    function claimRWRD(uint256 tokenId) external
    whenNotPaused()
    onlyOwnerOf(tokenId) {
        address originalOwner = HRSYToken.owners(tokenId);
        //compute the amount of unclaimed wins
        uint256 amount = wins[originalOwner] - rewarded[tokenId];
        if (amount > 0) {
            uint8 upgradeCounter;
            (,,,upgradeCounter) = HRSYToken.horseys(tokenId);
            require(upgradeCounter > 1,"You must upgrade this HRSY before claiming");
            //set this to the current counter to prevent claiming multiple times from same wins
            rewarded[tokenId] = wins[originalOwner];
            uint256 horseAmount = 0;
            if(upgradeCounter == 2) {
                horseAmount = config["RWRD0"] * amount;
            } else if(upgradeCounter == 3) {
                horseAmount = config["RWRD1"] * amount;
            } else  if(upgradeCounter == 4) {
                horseAmount = config["RWRD2"] * amount;
            }
            //credit the original creator some HORSE
            uint256 creatorDue = horseAmount / 100 * config["CREATOREQ"];
            if(creatorDue > 0) {
                _wallet.transferFromAndTo(address(_wallet),originalOwner,creatorDue);
            }
            //credit user the HORSE
            _wallet.transferFromAndTo(address(_wallet),msg.sender,horseAmount - creatorDue);
            
            emit RewardClaimed(tokenId,msg.sender,horseAmount);
        }
    }

    /**
        @dev Claiming HORSE from multiple reward HRSY
        @param tokenIds Array of ID of the token to burn
    */
    function claimMultRWRD(uint256[] tokenIds) external
    whenNotPaused() {
        uint256 totalHorseAmount = 0;

        //first try to claim from all tokens
        uint arrayLength = tokenIds.length;
        require(arrayLength <= 10, "Maximum 10 at a time");
        for (uint i = 0; i < arrayLength; i++) {
            require(HRSYToken.ownerOf(tokenIds[i]) == msg.sender, "Caller is not owner of this token");

            address originalOwner = HRSYToken.owners(tokenIds[i]);
            //compute the amount of unclaimed wins
            uint256 amount = wins[originalOwner] - rewarded[tokenIds[i]];
            if (amount > 0) {
                uint8 upgradeCounter;
                (,,,upgradeCounter) = HRSYToken.horseys(tokenIds[i]);
                require(upgradeCounter > 1,"You must upgrade this HRSY before claiming");
                //set this to the current counter to prevent claiming multiple times from same wins
                rewarded[tokenIds[i]] = wins[originalOwner];
                uint256 horseRewardAmount = 0;
                if(upgradeCounter == 2) {
                    horseRewardAmount = config["RWRD0"] * amount;
                } else if(upgradeCounter == 3) {
                    horseRewardAmount = config["RWRD1"] * amount;
                } else  if(upgradeCounter == 4) {
                    horseRewardAmount = config["RWRD2"] * amount;
                }
                uint256 creatorDue = horseRewardAmount / 100 * config["CREATOREQ"];
                if(creatorDue > 0) {
                    _wallet.transferFromAndTo(address(_wallet),originalOwner,creatorDue);
                }

                totalHorseAmount = totalHorseAmount + (horseRewardAmount - creatorDue);
                
                emit RewardClaimed(tokenIds[i],msg.sender,totalHorseAmount);
            }
        }

        if(totalHorseAmount > 0) {
            //credit user the HORSE
            _wallet.transferFromAndTo(address(_wallet),msg.sender,totalHorseAmount);
        }
    }

    /**
        @dev Allows a user to claim an HRSY for a fee in HORSE
            Cant be used on paused
            The sender has to be a winner of the race and must never have claimed a horsey from this race
        @param raceAddress The race's address
    */
    function claim(address raceAddress) external
    whenNotPaused()
    {
        //check that the user won
        bytes32 winner;
        bool res;
        uint256 betAmount;
        uint256 totalBetAmount;
        (res,winner,betAmount,totalBetAmount) = validator.validateWinner(raceAddress, msg.sender);
        require(res,"validateWinner returned false");

        //check that the user bet enough
        uint16 rewardHorseyCount = HRSYToken.count(msg.sender);
        uint256 minBet = config["MINBET"];
        if(rewardHorseyCount > 0) {
            //the minimal bet is based on the amount of reward horseys
            //use the 2x function 0.01 0.02 0.04 0.08 0.16 0.32 0.64 1.25
            minBet = rewardHorseyCount * config["MINBET"] / 100 * config["BETMULT"];
        }
        //make sure he respected the minimal bet amount
        require(totalBetAmount >= minBet,"You didnt bet enough and cant claim from this race!");

        uint256 poolFee = config["CLAIMFEE"];
        
        //get the HORSE from user account
        _processPayment(msg.sender,poolFee);
       
        //unique property is already be checked by minting function
        uint256 id = _generate_horsey(raceAddress, msg.sender, winner, betAmount);
        //add this to the users wins counter
        wins[msg.sender] = wins[msg.sender] + 1;
        emit Claimed(raceAddress, msg.sender, id);
    }

    /**
        @dev Allows a user to claim a list of HRSY tokens for a fee in HORSE
            Reduces a bit the gas cost per token
            Cant be used on paused
            The sender has to be a winner of the race and must never have claimed a horsey from this race
        @param raceContractIds Array of races addresses
    */
    function claimMult(address[] raceContractIds) external
    whenNotPaused()
    {
        //useful variables
        bytes32 winner;
        bool res;
        uint256 betAmount;
        uint256 totalBetAmount;
        //first try to claim all tokens
        uint arrayLength = raceContractIds.length;

        require(arrayLength <= 10, "Maximum 10 at a time");
        uint16 length = uint16(arrayLength);
        for (uint i = 0; i < arrayLength; i++) {
            //check that the user won
           
            (res,winner,betAmount,totalBetAmount) = validator.validateWinner(raceContractIds[i], msg.sender);
            require(res,"validateWinner returned false");

            //check that the user bet enough
            uint16 rewardHorseyCount = HRSYToken.count(msg.sender);
            uint256 minBet = config["MINBET"];
            if(rewardHorseyCount > 0) {
                //the minimal bet is based on the amount of reward horseys
                //use the 2x function 0.01 0.02 0.04 0.08 0.16 0.32 0.64 1.25
                minBet = rewardHorseyCount * config["MINBET"] / 100 * config["BETMULT"];
            }
            //make sure he respected the minimal bet amount
            require(totalBetAmount >= minBet,"You didnt bet enough and cant claim from this race!");

            //unique property is already be checked by minting function
            uint256 id = _generate_horsey(raceContractIds[i], msg.sender, winner, betAmount);
            emit Claimed(raceContractIds[i], msg.sender, id);
        }
        //add this to the users wins counter
        wins[msg.sender] = wins[msg.sender] + length;
        //now process the payment
        uint256 poolFee = config["CLAIMFEE"];
        //get the HORSE from user account
        _processPayment(msg.sender,poolFee*arrayLength);
    }

    /**
        @dev Allows a user to give a horsey a name or rename it
            This functions' cost is renamingFeePerChar * length(newname)
            Cant be called while paused
        @param tokenId ID of the horsey to rename
        @param newName The name to give to the horsey
    */
    function rename(uint256 tokenId, string newName) external 
    whenNotPaused()
    onlyOwnerOf(tokenId) 
    {
        uint256 renamingFee = config["RENAMEFEE"] * bytes(newName).length;

        uint256 poolFee = renamingFee;
        
        //get the HORSE from user account
        _processPayment(msg.sender,poolFee);

        //store the new name
        HRSYToken.storeName(tokenId,newName);
        emit Renamed(tokenId,newName);
    }

    /**
        @dev Allows a user to burn a token he owns to get HORSE
            Cant be called while paused
        @param tokenId ID of the token to burn
    */
    function burn(uint256 tokenId) external 
    whenNotPaused()
    onlyOwnerOf(tokenId) {
        uint8 upgradeCounter;
        address contractId;
        uint32 betAmountFinney;
        (,contractId,betAmountFinney,upgradeCounter) = HRSYToken.horseys(tokenId);
        uint256 betAmount = uint256(_shiftLeft(bytes32(betAmountFinney),15));
        uint amountHXP = 0;
        uint fee = 0;
        if(upgradeCounter == 0) {
            amountHXP = config["BURN0"];
            fee = config["BURNFEE0"];
        } else if(upgradeCounter == 1) {
            amountHXP = config["BURN1"];
            fee = config["BURNFEE1"];
        } else {
            revert("You can't burn this token");
        }
        //if the bet is superior to minimal bet an HXP bonus could apply
        if((betAmount >= config["MINBET"])) {
            uint256 maxBonus = config["MAXBET"] / 100 * config["BURNMULT"];
            uint burnBonus = betAmount / config["MAXBET"] * maxBonus;
            //clamp the HXP bonus
            if(burnBonus > maxBonus) {
                burnBonus = maxBonus;
            }
            amountHXP = amountHXP + burnBonus;
        }
        
        uint32 timestamp = validator.getRaceTime(contractId);
        //SPECIAL CODE FOR BONUS PERIOD
        if((timestamp > config["BPERIODBEGIN"]) && (timestamp < config["BPERIODEND"])) {
            amountHXP = amountHXP / 100 * config["BONUSMULT"];
        }
        //destroy horsey
        HRSYToken.unstoreHorsey(tokenId);

        //credit this user HORSE from the HORSE fund
        _wallet.creditHXP(msg.sender,amountHXP);

        uint256 poolFee = fee;
        
        //get the HORSE from user account
        _processPayment(msg.sender,poolFee);    
        
        emit Burned(tokenId);
    }

    /**
        @dev Allows a user to burn multiple tokens at once
            Cant be called while paused
        @param tokenIds Array of ID of the token to burn
    */
    function burnMult(uint256[] tokenIds) external 
    whenNotPaused() {
        //used multiple times
        uint8 upgradeCounter;
        address contractId;
        uint32 betAmountFinney;
        uint256 totalAmountHXP = 0;
        uint256 totalPoolFee = 0;
        require(tokenIds.length <= 10, "Maximum 10 at a time");
        //first try to burn all tokens
        for (uint i = 0; i < tokenIds.length; i++) {
            require(HRSYToken.ownerOf(tokenIds[i]) == msg.sender, "Caller is not owner of this token");

            (,contractId,betAmountFinney,upgradeCounter) = HRSYToken.horseys(tokenIds[i]);
            uint256 betAmount = uint256(_shiftLeft(bytes32(betAmountFinney),15));
            uint amountHXP = 0;

            if(upgradeCounter == 0) {
                amountHXP = config["BURN0"];
                totalPoolFee = totalPoolFee + config["BURNFEE0"];
            } else if(upgradeCounter == 1) {
                amountHXP = config["BURN1"];
                totalPoolFee = totalPoolFee + config["BURNFEE1"];
            } else {
                revert("You can't burn this token");
            }
            //if the bet is superior to minimal bet an HXP bonus could apply
            if((betAmount >= config["MINBET"])) {
                uint256 maxBonus = config["MAXBET"] / 100 * config["BURNMULT"];
                uint burnBonus = betAmount / config["MAXBET"] * maxBonus;
                //clamp the HXP bonus
                if(burnBonus > maxBonus) {
                    burnBonus = maxBonus;
                }
                amountHXP = amountHXP + burnBonus;
            }
            
            uint32 timestamp = validator.getRaceTime(contractId);
            //SPECIAL CODE FOR BONUS PERIOD
            if((timestamp > config["BPERIODBEGIN"]) && (timestamp < config["BPERIODEND"])) {
                amountHXP = amountHXP / 100 * config["BONUSMULT"];
            }
            //destroy horsey
            HRSYToken.unstoreHorsey(tokenIds[i]);

            totalAmountHXP = totalAmountHXP + amountHXP;
            
            emit Burned(tokenIds[i]);
        }

        //get the HORSE from user account
        _processPayment(msg.sender,totalPoolFee);    
            
        //credit this user HXP for all the HRSY he burned
        _wallet.creditHXP(msg.sender,totalAmountHXP);
    }

    /**
        @dev Allows to upgrade a horsey to increase its upgradeCounter value
            Cant be called while paused
        @param tokenId ID of the horsey to upgrade
    */
    function upgrade(uint256 tokenId) external 
    whenNotPaused()
    onlyOwnerOf(tokenId)
    {
        uint8 upgradeCounter;
        (,,,upgradeCounter) = HRSYToken.horseys(tokenId);
        uint amountHXP = 0;
        if(upgradeCounter == 0) {
            //create a "rare" HRSY
            amountHXP = config["UPGR0"];
        } else if(upgradeCounter == 1) {
            //create a "reward" HRSY
            amountHXP = config["UPGR1"];
            //this is a new RWRD HRSY, store the Original Owner
            HRSYToken.storeOwner(tokenId,msg.sender);
            //and increase his RWRD count
            HRSYToken.storeCount(msg.sender,HRSYToken.count(msg.sender)+1);
        } else if(upgradeCounter == 2) {
            //upgrade a "reward" HRSY to lvl 2
            amountHXP = config["UPGR2"];
        } else if(upgradeCounter == 3) {
            //upgrade a "reward" HRSY to lvl 3
            amountHXP = config["UPGR3"];
        } else {
            revert("token already at maximum");
        }
        //make sure we wont lose any rewards by upgrading a HRSY with left wins to claim
        if(upgradeCounter >= 2) {
            require(rewarded[tokenId] == wins[msg.sender],"You must claim your rewards before upgrading");
        }
        //set this to the current counter value every time a RWRD HRSY is created or upgraded to prevent claiming from past races
        if(upgradeCounter >= 1) {
            rewarded[tokenId] = wins[msg.sender];
        }
        
        //update the HRSY level
        HRSYToken.modifyHorseyUpgradeCounter(tokenId,upgradeCounter+1);
        //consume the required HXP
        require(_wallet.balanceOfHXP(msg.sender) >= amountHXP,"Insufficient HXP funds");
        _wallet.spendHXP(msg.sender,amountHXP);

        uint256 poolFee = config["UPGRFEE"];
        
        //get the HORSE from user account
        _processPayment(msg.sender,poolFee);   
        emit Upgraded(tokenId);
    }

    /**
        @dev Allows to purchase HXP using HORSE
        @param amount Amount of HXP to buy
    */
    function purchaseHXP(uint256 amount) external
    whenNotPaused() {
        require(amount > 0,"You must purchase at least 1 HXP");
        uint256 horseAmount = amount / config["CONVRATE"];
        uint256 fee = (horseAmount / 100 * config["CONVFEE"]);
        uint256 total = fee + horseAmount;
        //small part of the pool belongs to dev, store this amount here
        devCut = devCut + (fee / 100 * config["DEVEQ1"]);
        
        require(_wallet.balanceOf(msg.sender) >= total,"Insufficient HORSE funds");
        _wallet.transferFromAndTo(msg.sender,address(_wallet),total);
        _wallet.creditHXP(msg.sender,amount);

        emit HXPPurchased(msg.sender,amount);
    }

    /// @dev creates a special token id based on the race and the coin index
    function _makeId(address race, address sender, bytes32 coinIndex) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(race, sender, coinIndex)));
    }

    /**
        @dev Internal function to generate a HRSY token
            we then use the ERC721 inherited minting process
            the dna is a bytes32 target for a keccak256. Not using blockhash
            finaly, a bitmask zeros the first 2 bytes for rarity traits
        @param race Address of the associated race
        @param eth_address Address of the user to receive the token
        @param coinIndex The index of the winning coin
        @param betAmount Amount bet on this horse
        @return ID of the token
    */
    function _generate_horsey(address race, address eth_address, bytes32 coinIndex, uint256 betAmount) internal returns (uint256) {
        uint256 id = _makeId(race, eth_address, coinIndex);
        //generate dna and leave 0 in the rarity bit
        bytes32 dna = _shiftRight(keccak256(abi.encodePacked(race, coinIndex)),16);
        //storeHorsey checks if the token exists before minting already, so we dont have to here
        uint32 betAmountFinney = uint32(_shiftRight(bytes32(betAmount),15)); //store the bet amount in finney not wei to save space
        HRSYToken.storeHorsey(eth_address,id,race,dna,betAmountFinney,0);
        return id;
    }

    /**
        @dev Helpers to process payments in HORSE and applying fees
    */
    function _processPayment(address from, uint256 amount) internal {
        //get the HORSE from user account
        //dont process if amount is 0 (its allowed though)
        if(amount > 0) {
            //small part of the pool belongs to dev, store this amount here
            devCut = devCut + (amount / 100 * config["DEVEQ2"]);
            //fetch the HORSE from the address and credit it
            _wallet.transferFromAndTo(from,address(_wallet),amount);
        }   
    }

    /// @dev shifts a bytes32 right by n positions
    function _shiftRight(bytes32 data, uint n) internal pure returns (bytes32) {
        return bytes32(uint256(data)/(2 ** n));
    }

    /// @dev shifts a bytes32 left by n positions
    function _shiftLeft(bytes32 data, uint n) internal pure returns (bytes32) {
        return bytes32(uint256(data)*(2 ** n));
    }

    /// @dev requires the address to be non null
    modifier validAddress(address addr) {
        require(addr != address(0),"Address is zero");
        _;
    }

    /// @dev requires that the user isnt feeding a horsey already
    modifier onlyOwnerOf(uint256 tokenId) {
        require(HRSYToken.ownerOf(tokenId) == msg.sender, "Caller is not owner of this token");
        _;
    }
}