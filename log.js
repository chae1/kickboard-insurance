var Web3 = require('web3');

var web3 = new Web3(new Web3.providers.WebsocketProvider('wss://kovan.infura.io/ws/v3/5d1bcba9738349e3a7b93176f97dd616'));

web3.eth.subscribe('logs', {
	address: '0x377e020948ad84d5d5177feeb5dbf0c0b6e97319',
	topics : [null]
}, function(error, result) {
	if (error) {
		console.log("error", error);
	}
}).on("connected", function(subscriptionId) {
	console.log("subscrpitionId : ", subscriptionId);
}).on("data", function(log) {
	console.log("log", log);
});
