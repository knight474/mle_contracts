pragma solidity ^0.4.24;

/**
    @dev Interface of the HRSY token
*/
interface IHRSYToken {
    /// @dev Maps all token ids to a unique Horsey
    function horseys(uint256 tokenId) external view returns ( bytes32 dna, address race, uint32 betAmountFinney, uint8 upgradeCounter);
    /// @dev Maps a horsey token id to the horsey name
    function names(uint256 tokenId) external view returns (string);
    /// @dev Maps a user to the amount of reward horseys he created
    function count(address client) external view returns (uint16);
    /// @dev Maps a RWRD HRSY token id to its original owner
    function owners(uint256 tokenId) external view returns (address);
    /// @dev Master is the current Horsey contract using this coin
    function master() external view returns (address);
    /**
        @dev Stores a horsey name
        @param tokenId Horsey token id
        @param newName New horsey name
    */
    function storeName(uint256 tokenId, string newName) external;
    /**
        @dev Stores a horsey owner
        @param tokenId Horsey token id
        @param newOwner New horsey owner
    */
    function storeOwner(uint256 tokenId, address newOwner) external;
    /**
        @dev Stores the amount of reward horseys a player owns
        @param client player address
        @param newCount New horsey count
    */
    function storeCount(address client, uint16 newCount) external;
    /**
        @dev stores a new horsey
        @param client owner of the new horsey
        @param tokenId id of the newly minted token
        @param race contract id of the related race
        @param dna generated dna
        @param betAmountFinney amount of ETH (in finney) placed on this HORSE during bet
        @param upgradeCounter number of upgrades this horsey had
    */
    function storeHorsey(address client, uint256 tokenId, address race, bytes32 dna, uint32 betAmountFinney, uint8 upgradeCounter) external;
    /**
        @dev overwrite the dna value of an existing horsey
        @param tokenId ID of the HRSY token to modify
        @param dna the new DNA value
    */
    function modifyHorseyDna(uint256 tokenId, bytes32 dna) external;
    /**
        @dev overwrite the upgrade counter value of an existing horsey
        @param tokenId ID of the HRSY token to modify
        @param upgradeCounter the new value
    */
    function modifyHorseyUpgradeCounter(uint256 tokenId, uint8 upgradeCounter) external;
    /**
        @dev Allows to burn a HRSY token
        @param tokenId ID of the token to burn
    */
    function unstoreHorsey(uint256 tokenId) external;
    /// @dev returns the address of tokenId's token owner
    function ownerOf(uint256 tokenId) external returns (address);
}