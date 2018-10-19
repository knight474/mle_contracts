pragma solidity ^0.4.24;

interface IHorseyWallet {
    /**
        @dev Transfer HORSE from the wallet to the user
        @param amount Amount of HORSE to withdraw from this wallet
    */
    function withdraw(uint256 amount) external;
    /**
        @dev Transfer HORSE from the wallets' pool to the devs
        @param amount Amount of HORSE to withdraw from this wallets' pool
    */
    function withdrawPool(uint256 amount) external;
    /// @dev map of approved addresses to use user balance from this wallet
    function approvedSpenders(address account) external view returns (bool);
    /// @dev Balances in horse owned by users
    function balanceOf(address account) external view returns (uint256);
    /**
        @dev Allows an approved spender to withdraw any amount of HORSE from any user!!!
        @param account_from Account to transfer HORSE from
        @param account_to Account to transfer HORSE to
        @param amount Amount of HORSE to transfer
     */
    function transferFromAndTo(address account_from, address account_to, uint256 amount) external;
    function balanceOfHXP(address account) external view returns (uint256);
    /**
        @dev Used to add HXP
            Funds are stored in balanceOfHXP[address(this)]
        @param amount Amount of HXP to add to the funds account
    */
    function creditHXP(address account, uint256 amount) external;
    /**
        @dev Used to add HXP
            Funds are stored in balanceOfHXP[address(this)]
        @param amount Amount of HXP to add to the funds account
    */
    function spendHXP(address account, uint256 amount) external;

    function owner() external view returns (address);

    /**
        @dev Allows the owner to add addresses which can withdraw from this contract without validation
        @param spender The address of an allowed spender
    */
    function addApprovedSpender(address spender) external;

    /**
        @dev Disallows the owner to add addresses which can withdraw from this contract without validation
        @param spender The address of an allowed spender
    */
    function removeApprovedSpender(address spender) external;
}