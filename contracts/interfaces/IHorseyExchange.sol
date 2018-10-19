pragma solidity ^0.4.24;

interface IHorseyExchange {
   /**
        @dev Allows the owner to change market fees
        @param fees The new fees to apply (can be zero)
    */
    function setMarketFees(uint256 fees) external;

    /**
        @dev Allows the owner to change dev equities
        @param equity The new equity to apply (can be zero)
    */
    function setDevEquity(uint256 equity) external;

    /**
        @dev Allows the owner to change original token creator equity
        @param equity The new equity to apply (can be zero)
    */
    function setCreatorEquity(uint256 equity) external;

    /**
        @dev Owner can withdraw the current HORSE balance
    */
    function withdraw() external;

    /// @dev inherited from ownable and pausable
    function owner() external view returns (address);
    function pause() external;
    function unpause() external;
}