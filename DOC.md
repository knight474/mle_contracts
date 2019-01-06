# Ethorse passive : technical overview

## On automatization and gas costs

The EVM (Ethereum Virtual Machine) is generally pretty bad in automatization since every action must be trigerred by an external source (an address) and provided enough gas for execution. Moreso, every action is limited in complexity since a maximum of 7M gas is allowed per transaction.
Therefore some questions are raised about how to handle the contract needs as defined in "Ethorse Passive : Functionality Overview".

For example the point 2 : "Contract has to automatically distribute winnings by address" cannot be implemented in the sence that we can't automatically send ETH to every player address. Same goes for the automatic betting.

### The withdrawal pattern

[The withdrawal pattern](https://medium.com/@jgm.orinoco/why-use-the-withdrawal-pattern-d5255921ca2a) is designed so all users are treated the same by the system, as a group and do not require specific management through time. The situation of a specific user is resolved when he executes a function on the contract and therefore pays for the cost.
A typical example is when the ethorse contract allocates funds to pay the winners after a race, and then the players have to claim their winnings themselves.
Without the withdrawal pattern, the ethorse contract would have to loop through all the winnings addresses and send them the correct amount of ETH. Meaning an ethorse server would have to call a function to distribute winnings + provide a possibly very large amount of gas. Moreso, if the race was popular and we have too many winners, 7M gas could prove to be too limited and the winnings could end up locked up forever or until EVM rased the block gas limit.

### About centralization

Generaly speaking centralization in crypto-land is **BAD**.

Two reasons for that:
1. Users will have to trust the system at some point
2. It adds running costs in server hosting and possible processing gas
3. Renders the dApp technically non dapp since without the server, functionality is hindered

It is however necessary for any automatic behaviour and can be done with moderate to none trust required.

**A partial centralization is possible without breaking the trust.**

In order for this to work, the server must be able to trigger the execution of contract code, but not change the fundamental behaviour of the system.
As an example lets imagine a withdrawal pattern situation : the contract code contains all the data to figure out how much of the winnings a user can claim. But now, instead of the users withdrawing their winnings through a function, we have a function callable by anyone (or only server) we call ***payX([user address])*** which will effectively compute how much the user is owned and will send the right amount of ETH to him.

In this configuration, we respect the fact that each user will be handled through a seperate call and thus not reach for maximum block gas limit. Also, we provide any "friendly" external actor the ability to trigger the payement for any user at will and pay the transaction costs. The actor can only have access to this function and has no control over where the funds go. In case of failure of the actor, the user who did not receive the winnings can always call this function himself making this fault-resistant.

Now, we can write this friendly server ourselves and publish its specifications and code, thus insuring users trust.
The dApp is technically not decentralized anymore, BUT if we take our server down, the community can easily bring it online by itself and keep the application running, insuring the most important part of decentralized applications : **they can only die when nobody cares**.

## Implementation suggestion 1

### Smart contract part

#### Usage

1. The user deposits N ETH to his name into the contract
2. Part of his funds go into the "3%" fund (*see note 1*)
3. The user must then UNPAUSE the auto betting by selecting one or 2 pairs and ratios (50/50, 70/30, ...) + amount per race + max races per day
4. ~~The user can select if any winnings will go back to the pool (default) or kept safe elsewhere~~
5. The user can PAUSE the auto betting anytime and if all the races he took part in are resolved, he can withdraw or change the auto betting settings to unpause

#### Rules

1. Ethorse 2.5% dividends also go into the "3%" fund
2. A certain amount of ETH is available to the auto betting system

#### note 1 
How do we figure out how much goes to everyone?


### Server part


## Passive income
