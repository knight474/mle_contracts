# PROGRESS

| Contract                | Description                                                  | State              | Tests                |
| ----------------------- | ------------------------------------------------------------ | ------------------ | -------------------- |
| HorseyExchange          | Selling HRSY tokens on a private DEX                         | Draft 2            | TODO                 |
| HorseyGame              | The main game contract                                       | Draft 2            | In progress          |
| HorseyWallet            | Handles HORSE and HXP holdings of MLE players                | Draft 1            | Done                 |
| HRSYToken               | ERC721 token, deployed only once and can't be changed        | Draft 1            | Done                 |
| RaceValidator           | Allows to validate from the EVM that a player won a race     | Draft 1            | Done                 |
| WalletUser              | Just a helper contract handling links to HorseyWallet        | Draft 1            | NA                   |
| HorseyPilot             | Democratic control contract owner of all Horsey contracts    | Draft 1            | Not started          |
| HORSEDEX                | The ETH/HORSE DEX contract                                   | Draft 1            | Not started          |


# INSTALL

I assume you have npm installed.

## Getting a test blockchain
- Install Ganache GUI=> http://truffleframework.com/ganache/
- OR install command line : npm install -g ganache-cli
- Run ganache
## Installing deployment framework
- Install truffle => "npm install -g truffle"

## Updating dependencies (openzeppelin)
- git submodule update --init --recursive

## Compiling the contracts (done automatically on migrate too)
"truffle compile"

##Testing
- Run Ganache
- go to /test => "truffle test filename.js"

# DEPLOYMENT DETAILS

- compiled contracts go to ./build
- openzeppelin referenced contracts are invisible and installed by openzeppelin
- contracts/test contains fake HORSE contracts and fake Betting contracts for testing purposes
- test/*.js contains test code, one file per contract

# MyLittleEthorse gamification project

## I] Current status

MyLittleEthorse is currently 2 applications.

### MLE Dapp
- **3D race viewer**
    - Real time race representation
    - Betting redirect to bet.ethorse.com
    - Change % and odds display
- **2D race viewer**
    - Mostly for mobile
- **Stats**
    - Daily data on all races
    - Helps TA bettors
- **Leaderboard**
    - Creates competition amongst players
    - New players can see others making profit
    - In the future, a volume-based leaderboard could be used to provide additional rewards (ETH) to active players
- **Personal stats**
    - See how well you do compared to others
- **HRSY Upgrade/Rewards UI (in development)**
    - View HRSY assets (Basic, Rare, Rewards)
    - Select Basic, Rare and Rewards tokens for upgrade 
    - View HXP balance and spend HXP to upgrade tokens 
    - View HXP required to upgrade HRSYs to next level 
    - Select Rare and Rewards HRSYs to sell on market 
    - Burn Basic and Rare HRSYs for HXP (HRSY Experience Points) 
- **HRSY Market (in development)**
    - View Basic and Rewards HRSYs on sale by other players 
    - Purchase Rare and Rewards HRSYs from other players (for HORSE)
    - Exchange HORSE for HXP 
- **Localization**
    - 4 languages so far

---

### MLE API
- **JSON formatted access to stats**
    - 3rd party dapps can use
- **CSV data**
    - Helps TA players
## II] Projects
### Mobile version
Currently the mobile version is 90% ready. It will provide with the ability to follow races anywhere.
3D is disabled on mobile to lower data usage.
### Weekly leaderboards
We want to display more user stats to increase competition and to allow rewards and prizes.
For example a leaderboard for every week including a live one for the current week.
### New race track
A classic stadium view where Horseys run in circles with a finish line.
### HRSY crypto collectible/rewards token on mainnet

New "Stables" UI will be developed to allow players to view HRSYs according to type (Basic, Rare, Rewards); spend HXP to upgrade HRSYs, etc. 
Users will be able to claim, rename, upgrade them (Basic --> Rare --> Rewards [I, II, III)])
The 3d model representing horseys is procedural and using a DNA system.
The DNA of each horsey is bacially keccak256(raceContractId+coinSymbol) + some rarity mecanics.
Dna is made of 2 pieces :
RARITY BITS . . . . . . . . . . . . .SKIN DATA
[---16 bits---][----------------240 bits------------------]

This ensures that each HRSYs skin is unique to its corresponding race.
We use the same system to represent the horseys running on track, so the player can preview what the possible HRSY will look like.

**As discussed, we are currently rewriting our contracts to accept HORSE as payments instead of ETH in all of our payable functions.**

An HRSY has 3 possible states :
* Basic 
* Rare
* Reward (Three levels of rewards; Level I delivers lower dividends than Level III)

An HRSY in reward mode is providing additional revenue to the player when he wins races (in HORSE tokens).

We plan on having fees for upgrading, renaming and trading HRSY (a DEX is being built for that currently).
Most of these fees will go into a common pool for distributing HORSE to players owning reward HRSYs.
A small part will however go into MLE's revenue. Exactly how much could be adjusted at any point after release.
To jumpstart the economy, we ask the Ethorse devs to provide an initial HORSE infusion of 600-750k, which will be used to provide rewards, provide liquidity for the DEX etc.

The goal for players would be to get Reward horseys for every address he owns in order to optimize his profit (with each Ethorse win)/sell Reward HRSYs for HORSE (owners will earn HORSE "dividends" from the player he/she purchased the Rewards HRSY from).
We plan on having a limit (2) of how many Reward HRSY can be generated by a single address.
Upgrading HRSY is done by paying a fixed amount of HXP (HRSY Experience Points). HXP can be earned by either burning HRSY tokens, or purchased with a 10% fee using HORSE tokens.
Reward HRSYs are obtained by upgrading  one or more Rare HRSYs (using HXP)
Rare HRSY are obtained either directly by claiming them via Ethorse races they win (low probability of free rare HRSY drop), by upgrading a Basic HRSY; Rare HRSYs can also be purchased on the market using HORSE 

Rare and Rewards HRSYs will  be tradable on the market. 

![](https://s3.us-east-2.amazonaws.com/mledev/img6.jpg)

### HORSEDEX the ETH/HORSE pair exchange

The goal is to provide a contract which can use the provided HORSE pool to sell it for ETH.
This contract will allow users to place orders for HORSE for a price a bit below market price. The collected ETH is then used to purchase HORSE from markets.
The way it's supposed to work to remain a trustless solution : 
1/ The user selects the amount of HORSE to buy
2/ The user's client fetches the current price from exchanges, removes 5% and creates the transaction to HorseDex with the amount of HORSE to buy and the ETH payload
3/ HorseDex contract registers the order and emits an event
4/ A server watches the event and checks that the price of this order is indeed 5% below current exchange price
5/ If ok, the server sends a transaction to HorseDex to process the order, else it sends a transaction to decline it
6/ The user either gets his ETH back or the HORSE he ordered

## III] Smart Contracts

HRSYs are a special type of ERC721 token.
Main characteristics:
- Basic HRSYs Minted by claiming as prize for each ethorse race victory (Rare HRSYs can also be earned via Ethorse race wins)
- Unique 3d models
- Non unique name
- Can be renamed for a fee
- Rewards and Rare HRSYs are tradeable
- All HRSYs can be upgraded (using HXP)
- Rewards HRSYs can earn HORSE for its owner (these can be traded on the market)

HXP (HRSY Experience Points) are another type of ERC721 token
Main characteristics: 
- HXP can be "spent" to upgrade Basic, Rare and Rewards HRSYs
- HORSE can be exchanged (on DEX) for HXP (1 HXP =.3 HORSE)

### Structure

Currently the HRSY token is built with upgrades in mind.
It consists of 5 main modules. Different critical parts can be independently replaced while preserving HRSY holdings.
All contracts are controlled by a single "Pilot" contract with voting capabilities. A fixed set of voting keys is created allowing to vote for a proposal.
A proposal can change critical values inside the contracts.
The "Pilot" is yet to be drafted.

#### HRSYToken
The ERC721 token contract. It handles the storage of (Basic, Rare and Rewards) HRSY tokens.
It's built with minimal restriction and is basicaly a database. It should survive during upgrades and ensure nobody loses tokens.
It uses ownership pattern to allow a master contract to add, remove and change token properties at will.

| Function                                                                                     | Description                                                   |
| -------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| storeName(uint256 tokenId, string newName)                                                   | stores a horsey name                                          |
| storeHorsey(address client, uint256 tokenId, address race, bytes32 dna, uint8 upgradeCounter)| stores a new horsey                                           |
| modifyHorseyDna(uint256 tokenId, bytes32 dna)                                                | overwrite the dna value of an existing horsey                 |
| modifyHorseyUpgradeCounter(uint256 tokenId, uint8 upgradeCounter)                            | overwrite the upgrade counter value of an existing horsey     |
| unstoreHorsey(uint256 tokenId)                                                               | allows to burn a HRSY token                                   |

#### RaceValidator
Allows to test if a specific user did really win an Ethorse race.
It also contains an activable system where only races of a specific list are considered legit, for all the others it will return false. This is to use in case cheaters start to deploy fake contracts to claim HRSY tokens from them.
We expect to redeploy this contract often because it heavily relies on Betting.sol code.

<<<<<<< HEAD
=======

>>>>>>> cb810fad28a03e60a1e0abc5681bc890ae73a6c4
| Function                                                 | Description                                                                                |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| addLegitRace(address newRace)                            | Adds a new race to the legit races list                                                    | 
| validateWinner(address raceAddress, address eth_address) | Called by a contract to validate if eth_address is a winner of the race at raceAddress     |

#### HorseyWallet
Since HORSE is an ERC20 token, making users pay using it has some restrictions.
You can't call a function AND transfer HORSE at the same time, so you can't directly pay using HORSE. The approval/withdrawal pattern allows a third party to withdraw an amount of HORSE from the user, however we did not wish to send 2 transactions every time a user wished to buy something.
We decided to develop a wallet contract specific to MLE.
A user can deposit HORSE on it, and withdraw anytime. All Horsey contracts are allowed to process HORSE payments from this wallet.
HORSE developers have a special function they can call to add funds to the contract.

| Function                                                                      | Description                                                                                |
| ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| addFunds(uint256 amount)                                                      | Used to add funds (like a HORSE donation)                                                  |
| deposit(uint256 amount)                                                       | Transfer HORSE to this wallets balance                                                     |
| withdraw(uint256 amount)                                                      | Transfer HORSE from the wallet to the user                                                 |
| transferFromAndTo(address account_from, address account_to, uint256 amount)   | Allows an approved spender to withdraw any amount of HORSE from any user!!!                |
| addApprovedSpender(address spender)                                           | Allows the owner to add addresses which can withdraw from this contract without validation |


#### HorseyGame
The main game code. This contract allows claiming a new HRSY, renaming and upgrading it for different fees. Players can: 

-Burn Basic and Rare HRSYs for HXP
-Upgrade Rare and Rewards HRSYs using HXP
-Claim rewards from upgraded HRSY tokens
-Buy HXP Credits with HORSE
-Rename HRSY tokens

All fees go into equities distribution to the devs however (and the overall HORSE dividend pool) .
A set percent of these equities can be injected back into the reserved HORSE pool.
All purchases are done in HORSE, the user must have a credited HORSE account in HorseyWallet contract.

| Function                                      | Description                                                               |
| --------------------------------------------- | ------------------------------------------------------------------------- |
| claim(address raceAddress)                    | Allows a user to claim a special horsey with the same dna as the race one |
| claimMult(address[] raceContractIds)          | Allows a user to claim a multiple HRSY at once                            |
| claimRWRD(address raceAddress)                | Claiming HORSE from a reward HRSY                                         |
| claimMultRWRD(address raceAddress)            | Claiming HORSE from multiple reward HRSY                                  |
| renameHorsey(uint256 tokenId, string newName) | Allows a user to give a horsey a name or rename it                        |
| burn(uint256 tokenId)                         | Allows a user to burn a token he owns to get HXP                          |
| burnMult(uint256[] tokenIds)                  | Allows a user to burn multiple tokens for HXP                             |
| upgrade(uint256 tokenId)                      | Allows to upgrade a horsey to increase its upgradeCounter value           |
| claimRWRD(uint256 tokenId)                    | Allows to claim the reward in HORSE from a Reward HRSY token you own      |
| purchaseHXP(int256 amount)                    | Allows to buy HXP credits in exchange for HORSE                           |

#### HorseyExchange
This is the Horsey market, also called HRSY DEX. It allows for:

-Buying HORSE tokens (in exchange for ETH)
-Exchanging HORSE tokens for HXP (HXP is used to upgrade HRSY tokens from basic to rare to rewards; upgrading rewards tokens to deliver additional HORSE dividends; HORSE used to purchase HXP is added to the HORSE dividends pool)
-Decentralized exchange of Rare and Rewards HRSY tokens between players (and the transfer of HORSE rewards to players; either the original owner or a player who has purchased a Rewards HRSY on the exchange)
The market has fees (to be set in the future).

| Function                                          | Description                                                    |
| ------------------------------------------------- | -------------------------------------------------------------- |
| depositToExchange(uint256 tokenId, uint256 price) | Create a sale order                                            |
| cancelSale(uint256 tokenId)                       | Allows true owner of token to cancel sale at anytime           |
| purchaseToken(uint256 tokenId)                    | Performs the purchase of a token that is present on the market |
| withdraw()                                        | Owner can withdraw the current HORSE balance                   |

#### Pilot

The pilot allows voters to select a function to execute with a specific parameter. You can see the current set of executable functions below.
The pilot also distributes equities to mle developers.
Currently callable on vote functions :

| Function             | Usage                                                           |
| -------------------- | --------------------------------------------------------------- |
| setConfigValue       | Changes the value inside the config map                         |
| setValidator         | Changes the address of the RaceValidator contract               |
| setMarketFees        | Changes the % of every transaction the market takes as fees     |
| addApprovedSpender   | Adds a contract address allowed to operate the Wallet           |
| changeMaster         | Changes the address of the master contract for HRSYToken        |
| pause                | Pauses HorseyGame and HorseyExchange contracts                  |
| unpause              | Unpauses HorseyGame and HorseyExchange contracts                |

#### HorseDex

This contract allows trustless exchange on the ETH/HORSE pair.

| Function                                          | Usage                                                                 |
| ------------------------------------------------- | --------------------------------------------------------------------- |
| placeOrder(uint256 amount) external payable       | Places a new order for the sender for amount HORSE                    |
| cancelOrder()                                     | Allows a buyer to cancel his own order                                |
| rejectOrder(address buyer)                        | Used by the owner (server) to reject an order if price isnt agreeable |
| processOrder(address buyer)                       | Used by the owner (server) to fulfill an order if price is agreeable  |

## IV] Screenshots

![](https://s3.us-east-2.amazonaws.com/mledev/mobile.jpg)
![](https://s3.us-east-2.amazonaws.com/mledev/img1.jpg)
![](https://s3.us-east-2.amazonaws.com/mledev/img2.jpg)
![](https://s3.us-east-2.amazonaws.com/mledev/img3.jpg)
![](https://s3.us-east-2.amazonaws.com/mledev/img4.jpg)
![](https://s3.us-east-2.amazonaws.com/mledev/img5.jpg)
