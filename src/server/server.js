import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';



let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let specialTestAccount = null;
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
flightSuretyApp.options.gas = 900000; // necessary for some operations

// CONST
const NUMBER_OF_ORACLES = 30; //
const ORACLE_ACC_START_INDEX = 20;
const ORACLE_REG_FEE = "1"; // in ETH
const ORACLE_REG_FEE_WEI = Web3.utils.toWei(ORACLE_REG_FEE, "ether");
const SPECIAL_TEST_ACCOUNT_INDEX = 1; // this special web3 account should be registered as an AIRLINE, flights from the airline will always return a STATUS_CODE_LATE_AIRLINE

// Flight status codees
const STATUS_CODE_UNKNOWN = 0;
const STATUS_CODE_ON_TIME = 10;
const STATUS_CODE_LATE_AIRLINE = 20;
const STATUS_CODE_LATE_WEATHER = 30;
const STATUS_CODE_LATE_TECHNICAL = 40;
const STATUS_CODE_LATE_OTHER = 50;


// DATA
let ORACLE_INDICES = new Map(); // {address => [index1, index2, index3]}  


let Utils = {

  registerOracles: async function() {

    var oracleCount = 1;

    for (const account of ORACLE_INDICES.keys()) {
      let alreadyRegistered = await flightSuretyApp.methods.isOracleAlreadyRegistered().call({ from: account });
      // console.log(`is Oracle ${oracleCount} [${account}] already registered?: ${alreadyRegistered}`);
      if (!alreadyRegistered){
        // console.log(`about to register Oracle ${oracleCount} - [${account}]`);
        let registrationSuccessful = false;
        let attempt = 1;
        while(!registrationSuccessful && attempt <= 10) {
          try {
            await flightSuretyApp.methods.registerOracle().send({ from: account, value: ORACLE_REG_FEE_WEI });
            registrationSuccessful = true;
          } catch (error) {
              // console.log(`Registration for ${account} failed on attempt ${attempt} `);
              let sleepDurationMs = attempt * 2000;
              // console.log(`sleeping for ${attempt * 2} secs ..`);
              await new Promise(resolve => setTimeout(resolve, sleepDurationMs));
          } finally {
            if (attempt >=10 && !registrationSuccessful){
              console.log(`Registration for ${account} failed on attempt ${attempt} `);
              throw "All oracles could not be succesfully registered, please restart the server to try again ... "
            }
            attempt++
          }
        }

      };

      // populate indices
      // console.log('fetching indices ...');
      let indexes = await flightSuretyApp.methods.getMyIndexes().call({ from: account });
      let setIndexes = new Set(indexes);
      console.log(`Oracle ${oracleCount} [${account}] indexes are ${indexes}`);
      ORACLE_INDICES.set(account, setIndexes);

      oracleCount++;
    }

    console.log("Registration of Oracles completed successfully!");
  },

  getOracleAccounts: async function() {
    let accounts = await web3.eth.getAccounts();

    // console.log(accounts);
    // console.log(accounts.length);

    // popoulate oracle map

    let counter = 0;
    // console.log("I am running ....");

    while( counter < NUMBER_OF_ORACLES){
      // console.log("counter: ", ORACLE_ACC_START_INDEX + counter);
      let account = accounts[ORACLE_ACC_START_INDEX + counter];    
      // console.log("account: ", account);  
      if (account) {
        ORACLE_INDICES.set(account, new Set());  
      } else {
        const requiredAccountsCount = NUMBER_OF_ORACLES + ORACLE_ACC_START_INDEX;
        throw `Not enough web3 accounts to register oracles! At least ${requiredAccountsCount} accounts required. Please refer to ReadMe.`
      };
      counter++;
    };

    // update special test account value;
    specialTestAccount = accounts[SPECIAL_TEST_ACCOUNT_INDEX];
    console.log("Special test account set to: ", accounts[SPECIAL_TEST_ACCOUNT_INDEX]);
    // console.log("all data: ", ORACLE_INDICES)
  },

  isOracleRequestOpen: async function(flightDetails) {
    return await flightSuretyApp.methods.isOracleRequestOpenForIndex(
      flightDetails.airline, flightDetails.flight, flightDetails.timestamp, flightDetails.index
      ).call();
  },

  getRandomClusterResponse: function() {
    let statusList = [
      STATUS_CODE_UNKNOWN,
      STATUS_CODE_ON_TIME,
      STATUS_CODE_LATE_AIRLINE,
      STATUS_CODE_LATE_WEATHER,
      STATUS_CODE_LATE_TECHNICAL,
      STATUS_CODE_LATE_OTHER
    ];

    return statusList[Math.floor(Math.random()*statusList.length)];
  },

  sumbitOracleResponse: async function(oracleAccount, eventDetails, response) {
    //  // check if oracle is still accepting responses for flight
    // let stillAcceptingResponses = await Utils.isOracleRequestOpen(eventDetails);
    // console.log("response for if open: ", stillAcceptingResponses);
    // if (!stillAcceptingResponses) {
    //   console.log(`Oracle request now closed, Oracle [${oracleAccount}] skipping ..`)
    //   return
    // }
    //
    flightSuretyApp.methods.submitOracleResponse(
      eventDetails.index, eventDetails.airline, eventDetails.flight, eventDetails.timestamp, response
      ).send({from: oracleAccount}, (e, r) => {
          if (e) {
            console.error(`SUBMISSION FAILURE: [${oracleAccount} | ${eventDetails.airline}-${eventDetails.flight} - ${response}] - ${e.message}`);
          } else {
            console.log(`SUBMISSION SUCCESS: [${oracleAccount} | ${eventDetails.airline}-${eventDetails.flight} - ${response}]`);
          }
        });
  }

};


(async()=>{

  // initial setup
  await Utils.getOracleAccounts();
  await Utils.registerOracles();
  
  console.log("Listening for Oracle Request events ... ");

  // start processing events
  flightSuretyApp.events.OracleRequest({
    fromBlock: 0
  }, function (error, event) {
    if (error) console.log(error)
    processEvent(event);
});


})();


// async function startProcessingEvent(){
//     flightSuretyApp.events.OracleRequest({
//       fromBlock: 0
//     }, function (error, event) {
//       if (error) console.log(error)
//       console.log(event);
//       processEvent(event);
//   });
// };


async function processEvent(contractEvent){
  console.log('processing event: ', contractEvent.returnValues);

  let requestDetails = contractEvent.returnValues;
  let stillActive = await Utils.isOracleRequestOpen(requestDetails);
  console.log('order still open? ', stillActive);

  if(!stillActive){
    // prevents reprocessing events on restart
    console.log("oracle no longer accepting responses for this flight, skipping ...");
    return
  }

  // to simplify testing, flights for the first Airline regsitered with always return 
  // STATUS_CODE_LATE_AIRLINE
  // 


  // let clusterAResponse = "";
  // let clusterBResponse = "";
  // let clusterCResponse = "";

  // if (requestDetails.airline) {
  //   clusterAResponse = Utils.getRandomClusterResponse();
  //   clusterBResponse = STATUS_CODE_LATE_AIRLINE;
  //   clusterCResponse = STATUS_CODE_LATE_AIRLINE;
  // } else {
  //   clusterAResponse = Utils.getRandomClusterResponse();
  //   clusterBResponse = Utils.getRandomClusterResponse();
  //   clusterCResponse = clusterBResponse;
  // }

  ORACLE_INDICES.forEach((oraclesIndexes, account)=>{

      if(oraclesIndexes.has(requestDetails.index)){

        console.log(`Oracle [${account}] with indexes - `, oraclesIndexes, ` is responding to oracle request event with index ${requestDetails.index}`)
        
        var response = Utils.getRandomClusterResponse();

        if (requestDetails.airline == specialTestAccount) {
          response = STATUS_CODE_LATE_AIRLINE;
          console.log("Special airline deteced, overwiriting random response with: ", response);
        }
        
        Utils.sumbitOracleResponse(account, requestDetails, response);
      };
  });


};



const app = express();
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})

export default app;


