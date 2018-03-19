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
         * The user's predicted coin's price defined in dollar $ cents.
         */
        uint32 predictedPriceDollarCents;

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

        /**
         * Defines whenever the BetRound is still in progress, open for bets.
         */
        bool isOpen;
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
    event BetRoundWinner(uint roundId, address winner, uint winnerReward);
    event BetPlaced(uint roundId, address user, uint32 predictedPriceDollarCents);

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
        // Buy in must be higher than 0.01 ETH in Wei
        require(_betAmount > 10000000000000000);

        roundId = rounds.length++;
        BetRound storage round = rounds[roundId];
        round.startTimestamp = _startTimestamp;
        round.endTimestamp = _endTimestamp;
        round.resolutionTimestamp = _resolutionTimestamp;
        round.betAmount = _betAmount;
        round.organizer = msg.sender;
        round.isOpen = true;

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

    /**
     * Currently only the contract owner can close the BetRound and decide
     * the winner but that's not really in a "blockchain spirit" of doing things.
     *
     * A more advanced security alternative should be implemented where a system
     * can close the bet round automatically and take the price directly
     * from one of the exchanges.
     */
    function decideBetRoundWinner(
        uint _roundId,
        uint32 _finalBetRoundCoinPriceDollarCents
    ) public {
        BetRound memory betRound = rounds[_roundId];

        // BetRound was not found as the betAmount must be set and be greater than 0
        assert(betRound.betAmount > 0);
        // Is it already possible to finalize the BetRound?
        assert(now > betRound.resolutionTimestamp);
        // BetRound must be open
        assert(betRound.isOpen == true);
        // Only contract owner can choose a winner for now @todo
        assert(msg.sender == owner);
        // There were no bets, closing BetRound without choosing the winner!
        if (rounds[_roundId].bets.length == 0) {
            rounds[_roundId].isOpen = false;

            return;
        }

        uint32 closestBetPrice = 2 ** 32 - 1;
        address[] memory winners = new address[](betRound.bets.length);
        uint winnersCount = 0;

        for (uint i = 0; i < betRound.bets.length; i++) {
            uint32 betPrice = betRound.bets[i].predictedPriceDollarCents;
            uint32 betPriceDiff = 0;

            if (betPrice > _finalBetRoundCoinPriceDollarCents) {
                betPriceDiff = betPrice - _finalBetRoundCoinPriceDollarCents;
            } else {
                betPriceDiff = _finalBetRoundCoinPriceDollarCents - betPrice;
            }

            if (betPriceDiff < closestBetPrice) {
                // We have a new winner, reset the old array of winners.
                //
                // This is done because maybe two people bet the same price and in
                // such a case we want to add the current bet.user to the list instead
                // of resetting it.
                winners = new address[](betRound.bets.length);
                winnersCount = 0;
            }

            if (betPriceDiff <= closestBetPrice) {
                closestBetPrice = betPriceDiff;
                winners[i] = betRound.bets[i].user;
                winnersCount++;
            }
        }

        uint betRoundPricePool = betRound.bets.length * betRound.betAmount;
        // 1% fee goes to the BetRound organizer (contract owner)
        uint betRoundOrganizerFee = betRoundPricePool / 100;
        uint betRoundPricePoolAfterFee = betRoundPricePool - betRoundOrganizerFee;
        uint userReward = betRoundPricePoolAfterFee / winnersCount;

        // Close the BetRound before transferring the user reward to prevent "re-entrancy"
        rounds[_roundId].isOpen = false;

        // Transfer user rewards!
        for (uint wIndex = 0; wIndex < winners.length; wIndex++) {
            if (winners[wIndex] == address(0)) {
                continue;
            }

            winners[wIndex].transfer(userReward);

            BetRoundWinner(_roundId, winners[wIndex], userReward);
        }
    }

    function bet(
        uint _roundId,
        uint32 _predictedPriceDollarCents
    ) public payable returns (bool success) {
        BetRound storage betRound = rounds[_roundId];

        // BetRound was not found as the betAmount must be set and be greater than 0
        assert(betRound.betAmount > 0);
        // BetRound must be open for bets
        assert(betRound.isOpen == true);
        // User can only bet once in a round
        assert(roundsBetsByUser[msg.sender][_roundId].user != msg.sender);
        // User must send the required betting round buy in
        assert(msg.value == betRound.betAmount);

        uint myBetId = betRound.bets.length++;
        Bet storage myBed = betRound.bets[myBetId];
        myBed.user = msg.sender;
        myBed.predictedPriceDollarCents = _predictedPriceDollarCents;
        myBed.timestamp = now;

        roundsBetsByUser[msg.sender][_roundId] = myBed;

        BetPlaced(_roundId, msg.sender, _predictedPriceDollarCents);

        return true;
    }

    function getBalance() view public returns(uint balance) {
        return this.balance;
    }

    function () public {

    }
}