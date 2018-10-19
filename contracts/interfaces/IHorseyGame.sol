pragma solidity ^0.4.24;

interface IHorseyGame {
    /**
        @dev Change wallet address
        @param validatorAddress the new address
    */
    function setValidator(address validatorAddress) external;

    /**
        @dev Changes the amount of horse required to upgrade a horsey
        @param name Name of the value to change
        @param newValue The new value
    */
    function setConfigValue(bytes32 name, uint256 newValue) external;

    /**
        @dev Owner can withdraw the current HORSE balance
    */
    function withdraw() external;

    function owner() external view returns (address);
}