
const readline = require('readline-sync');
let report = readline.question("input your report: ");
//let report = "0x000000000000f6f3ed664fd0e7be332f035ec351acf1000000000000000a030700040a00000000000000000000000000000000000000000000000000000000000a05617364617300000000000000000000000000000000000000000000000000";
let privateKey = readline.question("input your privateKey: ");
//let privateKey = "7f6965ae260469425ae839f5abc85b504883022140d5f6fc9664a96d480c068d";
let Web3 = require('web3');
var web3 = new Web3('http://localhost:8545');
const messageHash = web3.utils.sha3(report);
let signature = web3.eth.accounts.sign(messageHash, privateKey);
console.log("R: " + signature.r);
console.log("S: " + signature.s);
console.log("V: " + signature.v);