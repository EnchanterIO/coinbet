# Idea

A decentralised smart contract application based on Ethereum blockchain that enables people to bet against each other in pursuit, competition of predicting token prices.

E.g:

I can create a **Betting Round** using [Coinbet.sol](https://github.com/EnchanterIO/coinbet/blob/master/contracts/Coinbet.sol) smart contract API like so:

```solidity
function createBetRound(
    uint _startTimestamp,
    uint _endTimestamp,
    uint _resolutionTimestamp,
    uint _betAmount,
    uint8 _coin
) public returns (uint roundId) {
```

Each **Betting Round** has its Start -> End period and a Resolution timestamp defined.

Betting period must end, at least 7 days before the winner resolution takes place, as it doesn't make sense to do ad-hoc bets as the last person betting would have the highest chance of guessing the Coin price.

Currently betting on the following coins is supported: 

```solidity
enum Coin {BTC, ETH, XRP}
```

Bets can be submitted using the **bet function**:

```solidity
function bet(uint _roundId, uint32 _predictedPriceCents) public payable returns (bool success) {
```

The transaction is validated and the value sent must be of the same amount of Wei as **Betting Round** defines.

**E.g:** 

If someone created a **Betting Round** on the XRP price with betting period finishing in 1 month and a resolution timestamp defined for 2 months from now on where each participant's "bet" must be of 1000000000000000000 Wei (1 Ether) then the bet transaction must hold 1000000000000000000 Wei in order for bet to be accepted.

# Todo

| Task  | Description |
| ------------- | ------------- |
| Winner resolution | Contract needs to have defined logic for choosing the winner of the Betting Round. This is tricky as external data (Coin price at resolution timestamp) from one of the exchanges in advance agreed on, must be provided and be trustworthy. |
| Tests  | Cover the whole contract with tests |
| Web interface | A web interface should be developed to make creation of Betting Rounds and Bets easier. |
| Deploy | The app should be deployed to a decentralised filesystem. |
| Fee | Fee cut logic should be included in the contract that sends to Coinbet developers an in-advance specified percentage cut after each Betting Round resolution. |

# Development collaboration

Get in touch with me via [Twitter](https://twitter.com/EnchanterIO) or create a new Issue to discuss the development. Looking forward!