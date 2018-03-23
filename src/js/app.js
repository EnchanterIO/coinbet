App = {
    web3Provider: null,
    contracts: {},

    init: function() {
        return App.initWeb3();
    },

    initWeb3: function() {
        if (typeof web3 !== 'undefined') {
            App.web3Provider = web3.currentProvider;
        } else {
            // If no injected web3 instance is detected, fall back to Ganache
            App.web3Provider = new Web3.providers.HttpProvider('http://localhost:7545');
        }
        web3 = new Web3(App.web3Provider);

        return App.initContract();
    },

    initContract: function() {
        $.getJSON('Coinbet.json', function(data) {
            // Get the necessary contract artifact file and instantiate it with truffle-contract
            var CoinbetArtifact = data;
            App.contracts.Coinbet = TruffleContract(CoinbetArtifact);

            // Set the provider for our contract
            App.contracts.Coinbet.setProvider(App.web3Provider);

            return App.displayBetRounds();
        });

        return App.bindEvents();
    },

    displayBetRounds: function() {
        var coinbetInstance,
            betRoundContainer = $('#bet-rounds'),
            betRoundTemplate = $('#bet-round-template');

        App.contracts.Coinbet.deployed().then(function (instance) {
            coinbetInstance = instance;

            return coinbetInstance.getBetRoundsIds.call();
        }).then(function(betRoundIds) {
            // Remove the loading message
            betRoundContainer.html("");

            for (var i = 0; i < betRoundIds.length; i++) {
                coinbetInstance.getBetRound.call(betRoundIds[i].toNumber()).then(function (betRound) {
                    betRoundTemplate.find('.panel-title').text(betRound[0].toNumber());
                    betRoundTemplate.find('.bet-start').text(new Date(betRound[1].toNumber() * 1000).toUTCString());
                    betRoundTemplate.find('.bet-end').text(new Date(betRound[2].toNumber() * 1000).toUTCString());
                    betRoundTemplate.find('.bet-resolution').text(new Date(betRound[3].toNumber() * 1000).toUTCString());
                    betRoundTemplate.find('.bet-coin').text(App.convertCoinToString(betRound[6].toNumber()));
                    betRoundTemplate.find('.bet-pricepool').text(web3.fromWei(betRound[5], 'Ether') + " ETH");
                    betRoundTemplate.find('.bet-buyin').text(web3.fromWei(betRound[4], 'Ether') + " ETH");
                }).finally(function () {
                    betRoundContainer.append(betRoundTemplate.html());
                });
            }
        }).catch(function(err) {
            console.log(err.message);
        });
    },

    createBetRound: function (start, end, resolution, buyinEth, coin) {
        var coinbetInstance;

        web3.eth.getAccounts(function(error, accounts) {
            if (error) {
                console.log(error);
            }

            var account = accounts[0];

            App.contracts.Coinbet.deployed().then(function(instance) {
                coinbetInstance = instance;

                return coinbetInstance.createBetRound(
                    new Date(start).getTime(),
                    new Date(end).getTime(),
                    new Date(resolution).getTime(),
                    web3.toWei(buyinEth, 'Ether'),
                    coin,
                    {from: account}
                );
            }).then(function(result) {
                $('#c-submit-btn').addClass('hide');
                $('#c-bet-round-success-container').removeClass('hide');

                console.log(result.tx);
                console.log(result.receipt);

                for (var i = 0; i < result.logs.length; i++) {
                    var log = result.logs[i];

                    if (log.event === 'BetRoundCreated') {
                        $('#c-bet-round-id').text(log.args.roundId.toNumber());
                        $('#c-bet-round-organizer').text(log.args.organizer);
                        $('#c-bet-round-transaction-hash').text(result.tx);
                    }
                }
            }).catch(function(err) {
                App.displayCreateBetRoundFormError(err + ". Please report the bug at https://github.com/EnchanterIO/coinbet/issues");
            });
        });
    },

    convertCoinToString: function (coinInt) {
        if (coinInt === 0) {
            return 'BTC';
        }

        if (coinInt === 1) {
            return 'ETH';
        }
        if (coinInt === 2) {
            return 'XRP';
        }
    },

    displayCurrentUtcTime: function () {
        $('#current-utc-time').html(new Date().toUTCString());
    },

    submitCreateBetRoundForm: function(e) {
        e.preventDefault();
        var $form = $(e.target),
            start = $form.find('#c-start-timestamp').val(),
            end = $form.find('#c-end-timestamp').val(),
            resolution = $form.find('#c-winner-timestamp').val(),
            buyIn = parseFloat($form.find('#c-buyin').val()),
            coin = parseInt($form.find('input[name=c-coin]:checked').val())
        ;

        App.removeCreateBetRoundFormError();

        if (!(coin >= 0)) {
            App.displayCreateBetRoundFormError("On which coin price should people be betting?");

            return;
        }

        if (buyIn < 0.01) {
            App.displayCreateBetRoundFormError("Minimum buy in is 0.01ETH");

            return;
        }

        App.createBetRound(start, end, resolution, buyIn, coin);
    },

    displayCreateBetRoundFormError: function(errorMessage) {
        var $form = $('#c-create-bet-round');

        $form.find('#c-error').text(errorMessage);
        $form.find('#c-error').removeClass('hide');
    },

    removeCreateBetRoundFormError: function() {
        if (!$('#c-error').hasClass('hide')) {
            $('#c-error').addClass('hide')
        }
    },

    bindEvents: function() {
        // $(document).on('click', '#create-bet-round', App.createBetRound)
        $('#c-start-timestamp').datetimepicker({
            format: 'yyyy-mm-dd hh:ii'
        });
        $('#c-end-timestamp').datetimepicker({
            format: 'yyyy-mm-dd hh:ii'
        });
        $('#c-winner-timestamp').datetimepicker({
            format: 'yyyy-mm-dd hh:ii'
        });
        $(document).on('submit', '#c-create-bet-round', App.submitCreateBetRoundForm);
        $('#myModal').on('hidden.bs.modal', function () {
            location.reload();
        })
    }
};

$(function() {
    $(window).load(function() {
        App.init();
        App.displayCurrentUtcTime();
    });
});
