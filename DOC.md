# Ethorse passive : technical overview

## Introduction on automation and gas costs

The EVM (Ethereum Virtual Machine) is generally pretty bad in automatization since every action must be trigerred by an external source (an address) and provided enough gas for execution. Moreso, every action is limited in complexity since a maximum of 7M gas is allowed per transaction.
Therefore some questions are raised about how to handle the contract needs as defined in "Ethorse Passive : Functionality Overview".

For example the point 2 : "Contract has to automatically distribute winnings by address" cannot be implemented in the sence that we can't automatically send ETH to every player address. Same goes for the automatic betting.

### The withdrawal pattern

[The withdrawal pattern](https://medium.com/@jgm.orinoco/why-use-the-withdrawal-pattern-d5255921ca2a) is designed so all users are treated the same by the system, as a group and do not require specific management through time. The situation of a specific user is resolved when he executes a function on the contract and therefore pays for the cost.
A typical example is when the ethorse contract allocates funds to pay the winners after a race, and then the players have to claim their winnings themselves.
Without the withdrawal pattern, the ethorse contract would have to loop through all the winnings addresses and send them the correct amount of ETH. Meaning an ethorse server would have to call a function to distribute winnings + provide a possibly very large amount of gas. Moreso, if the race was popular and we have too many winners, 7M gas could prove to be too limited and the winnings could end up locked up forever or until EVM rased the block gas limit.

### About centralization

Generaly speaking centralization in crypto-land is **BAD**.

Three reasons for that:
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

## Implementation thoughts

The first concern would be to limit the amount of transactions required. We will consider 2 scenarios for now.

### Worst case scenario

If we want each race contract to work like it does now, every user must be handled by a bot which sends transactions bet by bet.
With our current stable userbase (20 players), lets estimate Ethorse usage gas prices :

| Action  | Gas cost | Frequency per race |
| ------- | -------- | ------------------ |
| Bet     | 91000    | 2.0                |
| Claim   | 40000    | 0.66               |

So lets imagine that all of the 20 players bet on 2 races and claim 66% of the time, the average gas cost per user would be : 91000 * 2 + 40000 * 0.66 = 182000 + 26400 = 208400.
Lets round it up to 200k. If our very limited user base is using auto betting system : 20 * 200k = 4M gas per race.
The transactions need to arrive in less than an hour to be reliable, this means about 8 gwei to be on the safe side (at this moment, but needs to be dynamically adjusted). 
**Thats a 0.032 ETH per race in fees for only 20 players.**

If every player bets the minimum and plays 2 coins, 3 races a day (which will probably happend at launch) thats 0.4 eth of volume per race, 1.2 eth daily.
With a standard player brinding 0.06 eth of daily volume, thats 0.003 for the dividends pool, 0.0016 eth will go to gas fees, **auto betting costing more than 50% of the profit**.

### Pool scenario

#### A bit of perspective

In this case, we change the first idea of auto betting a bit, in order to allow for players to be regrouped into multiple pools.
The idea behind that is to represent the bet of multiple players with a single transaction on the race.
The person would be able to chose between multiple parameters, and depending on the settings, his funds will join a "betting pool" of players.
Lets find a reasonable amount of pools to represent our passive bettors.

If we allow people to bet 0.01, 0.02 and 0.05 eth per coin per race.
If we allow people to chose between betting on 3 or all races of a day.
If we allow people to bet on BTC,ETH,LTC or any Duo of these (6 possibilities).

We end up with 3 * 2 * 6 = 36 possibilities = 36 pools.
In this configuration, no matter how much users we have, the maximum amount of bets to place per race would be 36.
Some choices will be widely more popular and I expect that in practice, only 6-7 pools to be used at any given moment, but it's much harder to guess. Only used pools will end up as effective bets.

Depending on how much choice do we give to users, by using this technique, the amount of pools can rapidly grow and invalidate the technique.

It would be very efficient to define 10 pools and limit the choice to that.

#### Limitations

A user can't lose as long as the pool isnt empty, since he owns a part of this pool.
It's a bit harder to "pause" betting for a specific user.
It's harder to know how much of a pool belongs to a specific user.
Adding and removing people to and from the pool result in a complex computation of who owns what, the possibility of which is still to determine.

#### What happens to a pool

For example a 0.01 eth on ETH&LTC pool of 10 users will result in a bet of 0.1 eth on ETH and 0.1eth on LTC on every race.
Over time the pool would either grow or shrink compared to the other pools. Each user who deposited funds into the pool owns a % of it and can withdraw at any time except when a race is running.
Based on this, 

## Thoughts on passive income

Isn't passive income basically holding HORSE token? Most bettors seem to be interested by quick profit so I'm not 100% sure what is the audience for this idea.
The user will bet on the performance of a coin/a pairing over time instead of a specific race, as expected by Ethorse Passive. He will greatly reduce the risk of running out of funds, but also reduce the reward.
We could see an increased race volume and solve the "first bettor incentive" using that. However active bettors would be able to play the odds.