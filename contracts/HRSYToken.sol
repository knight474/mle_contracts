pragma solidity ^0.4.24;

import "../openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "../openzeppelin-solidity/contracts/token/ERC721/ERC721Full.sol";

/**
    @title HRSYToken Holding HRSY token
*/
contract HRSYToken is Ownable,ERC721Full {

    /**
        @dev Structure to hold Horsey collectible information
        @dev should be as small as possible but since its already greater than 256
        @dev lets keep it <= 512
    */
    struct Horsey {
        bytes32 dna;            /// @dev Stores the horsey dna
        //32 bytes
        address race;           /// @dev Stores the original race address this horsey was claimed from
        //32 + 20 bytes
        uint32  betAmountFinney;      /// @dev Amount of ETH bet to win this HRSY (in finney)
        //32 + 20 + 4 bytes
        uint8   upgradeCounter; /// @dev How many times this horsey has been upgraded
        //32 + 20 + 4 + 1 bytes
        //57 bytes
    }

    /// @dev Maps all token ids to a unique Horsey
    mapping(uint256 => Horsey) public horseys;

    /// @dev Maps a horsey token id to the horsey name
    mapping(uint256 => string) public names;

    /// @dev Maps a RWRD HRSY token id to its original owner
    mapping(uint256 => address) public owners;

    /// @dev Maps a user to the amount of reward horseys he created
    mapping(address => uint16) public count;

    /// @dev Master is the current Horsey contract using this coin
    address public master;

    /**
        @dev Contracts constructor
    */
    constructor() public
    Ownable()
    ERC721Full("HORSEY","HRSY") {
    }

    /**
        @dev Allows to change the address of the current Horsey contract
        @param newMaster Address of the current Horsey contract
    */
    function changeMaster(address newMaster) public
    validAddress(newMaster)
    onlyOwner() {
        master = newMaster;
    }

    /**
        @dev Stores a horsey name
        @param tokenId Horsey token id
        @param newName New horsey name
    */
    function storeName(uint256 tokenId, string newName) public
    onlyMaster() {
        require(_exists(tokenId),"token not found");
        names[tokenId] = newName;
    }

    /**
        @dev Stores a horsey owner
        @param tokenId Horsey token id
        @param newOwner New horsey owner
    */
    function storeOwner(uint256 tokenId, address newOwner) public
    onlyMaster() {
        require(_exists(tokenId),"token not found");
        owners[tokenId] = newOwner;
    }

    /**
        @dev Stores the amount of reward horseys a player owns
        @param client player address
        @param newCount New horsey count
    */
    function storeCount(address client, uint16 newCount) public
    onlyMaster() {
        count[client] = newCount;
    }

    /**
        @dev stores a new horsey
        @param client owner of the new horsey
        @param tokenId id of the newly minted token
        @param race contract id of the related race
        @param dna generated dna
        @param betAmountFinney amount of ETH (in finney) placed on this HORSE during bet
        @param upgradeCounter number of upgrades this horsey had
    */
    function storeHorsey(address client, uint256 tokenId, address race, bytes32 dna, uint32 betAmountFinney, uint8 upgradeCounter) public
    onlyMaster()
    validAddress(client) {
        //_mint checks if the token exists before minting already, so we dont have to here
        _mint(client,tokenId);
        Horsey storage hrsy = horseys[tokenId];
        hrsy.race = race;
        hrsy.dna = dna;
        hrsy.betAmountFinney = betAmountFinney;
        hrsy.upgradeCounter = upgradeCounter;
    }

    /**
        @dev overwrite the dna value of an existing horsey
        @param tokenId ID of the HRSY token to modify
        @param dna the new DNA value
    */
    function modifyHorseyDna(uint256 tokenId, bytes32 dna) public
    onlyMaster() {
        horseys[tokenId].dna = dna;
    }

    /**
        @dev overwrite the upgrade counter value of an existing horsey
        @param tokenId ID of the HRSY token to modify
        @param upgradeCounter the new value
    */
    function modifyHorseyUpgradeCounter(uint256 tokenId, uint8 upgradeCounter) public
    onlyMaster() {
        horseys[tokenId].upgradeCounter = upgradeCounter;
    }

    /**
        @dev Allows to burn a HRSY token
        @param tokenId ID of the token to burn
    */
    function unstoreHorsey(uint256 tokenId) public
    onlyMaster()
    {
        require(_exists(tokenId),"token not found");
        _burn(ownerOf(tokenId),tokenId);
        delete horseys[tokenId];
        delete names[tokenId];
    }

    /// @dev requires the address to be non null
    modifier validAddress(address addr) {
        require(addr != address(0),"Address must be non zero");
        _;
    }

     /// @dev requires the caller to be the master
    modifier onlyMaster() {
        require(master == msg.sender,"Address must be non zero");
        _;
    }
}