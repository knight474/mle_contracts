pragma solidity ^0.4.24;

import "./interfaces/IHorseyWallet.sol";
import "../openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

/**
    @title HorseyToken ERC721 Token
    @dev Horse contract - horse derives from Pausable
*/
contract WalletUser {
    /// @dev horse token access interface
    IERC20 internal _horseToken;

    /// @dev wallet of HORSEY
    IHorseyWallet internal _wallet;
    
    /**
        @dev Contracts constructor
            Initializes token data
            is pausable,ownable
        @param walletAddress Address of the current wallet contract
    */
    constructor(address walletAddress) 
    public {
        require(walletAddress != address(0),"Invalid wallet address!");
        _horseToken = IERC20(0x5B0751713b2527d7f002c0c4e2a37e1219610A6B);
        _wallet = IHorseyWallet(walletAddress);
    }
}