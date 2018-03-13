pragma solidity ^0.4.19;

contract Coinbet {
    /**
     * Do NOT shuffle these values as businest logic is based on their order.
     *
     * BTC uint value is 0
     * ETH uint value is 1
     * XRP uint value is 2
     */
    enum Coin {BTC, ETH, XRP}

    struct Bet {
        /**
         * The address of the user betting.
         */
        address user;

        /**
         * The user's predicted coin's price defined in cents.
         */
        uint32 predictedPriceCents;

        /**
         * Timestamp of the bet.
         */
        uint timestamp;
    }

    struct BetRound {
        /**
         * Defines when the betting period will start.
         */
        uint startTimestamp;

        /**
         * Defines until when will be possible to place the last bet.
         */
        uint endTimestamp;

        /**
         * Defines the time the smart contract should decide the winner based
         * on the closest bet.
         */
        uint resolutionTimestamp;

        /**
         * Defines the bet amount in Wei necessary to participate.
         */
        uint betAmount;

        /**
         * Defines the coin of which value the participants will be betting on.
         */
        Coin coin;

        address organizer;

        Bet[] bets;
    }

    address owner;
    BetRound[] public rounds;

    /**
     * Pointer between an address and rounds bets.
     *
     * An address can have only 1 bet per round.
     */
    mapping(address => mapping(uint => Bet)) public roundsBetsByUser;

    event BetRoundCreated(uint roundId, address organizer);
    event BetPlaced(uint roundId, address user, uint32 predictedPriceCents);

    function Coinbet() public {
        owner = msg.sender;
    }

    function createBetRound(
        uint _startTimestamp,
        uint _endTimestamp,
        uint _resolutionTimestamp,
        uint _betAmount,
        uint8 _coin
    ) public returns (uint roundId) {
        // Validate betting range
        require(_startTimestamp > now);
        require(_endTimestamp > _startTimestamp);
        // Betting period must end at least 7 days before the winner resolution
        // as it doesn't make sense to do ad-hoc bets as the last better has the
        // highest chance of guessing the price
        require(_resolutionTimestamp > _endTimestamp + 7 days);
        require(_coin == uint8(Coin.BTC) || _coin == uint8(Coin.ETH) || _coin == uint8(Coin.XRP));
        require(_betAmount > 0);

        roundId = rounds.length++;
        BetRound storage round = rounds[roundId];
        round.startTimestamp = _startTimestamp;
        round.endTimestamp = _endTimestamp;
        round.resolutionTimestamp = _resolutionTimestamp;
        round.betAmount = _betAmount;
        round.organizer = msg.sender;

        if (_coin == uint8(Coin.BTC)) {
            round.coin = Coin.BTC;
        } else if (_coin == uint8(Coin.ETH)) {
            round.coin = Coin.ETH;
        } else {
            round.coin = Coin.XRP;
        }

        BetRoundCreated(roundId, msg.sender);

        return roundId;
    }

    function bet(uint _roundId, uint32 _predictedPriceCents) public payable returns (bool success) {
        BetRound storage betRound = rounds[_roundId];

        // BetRound was not found as the betAmount must be set and be greater than 0
        assert(betRound.betAmount > 0);
        // User can only bet once in a round
        assert(roundsBetsByUser[msg.sender][_roundId].user != msg.sender);
        // User must send the required betting round buy in
        assert(msg.value == betRound.betAmount);

        uint myBetId = betRound.bets.length++;
        Bet storage myBed = betRound.bets[myBetId];
        myBed.user = msg.sender;
        myBed.predictedPriceCents = _predictedPriceCents;
        myBed.timestamp = now;

        roundsBetsByUser[msg.sender][_roundId] = myBed;

        BetPlaced(_roundId, msg.sender, _predictedPriceCents);

        return true;
    }

    function getBalance() view public returns(uint balance) {
        return this.balance;
    }

    function () public {

    }
}