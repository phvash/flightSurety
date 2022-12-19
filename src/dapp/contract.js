import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';

import Config from './config.json';
import web3 from 'web3';

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        this.web3 = new web3(new web3.providers.HttpProvider(config.url));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.flightSuretyData = new this.web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);
        this.initialize(callback);
        this.owner = null;
        this.airlines = [];
        this.passengers = [];
        this.activeAccount = null;
        this.accountRoleMapping = new Map();
        this.unassignedAccounts = [];
        this.airlinesObjs = new Map(); // could pontentially be fetching this from the contract directly (local mock of airline struct in data contract)
        this.participatingAirlines = new Set();
        this.availableFlights = null;
        this.insuredFlights = [];
        this.insuredFlightsMap = new Map();
    
        // Increase low gas limit since some operations would otherwise fail
        this.flightSuretyData.options.gas = 900000;
        this.flightSuretyApp.options.gas = 900000;
    }

    initialize(callback) {
        this.web3.eth.getAccounts((error, accts) => {

            console.log('error: ', error);
            console.log('accounts inits', accts);
           
            this.owner = accts[0];
            this.accountRoleMapping.set(accts[0], 'Contract Owner')

            this.activeAccount = accts[1];

            // let counter = 1;
            // let names = ['', 'One', 'Two', 'Three', 'Four', 'Five']
            
            // while(this.airlines.length < 5) {
            //     this.accountRoleMapping.set(accts[counter], 'Airline');
            //     this.airlinesObjs.set(accts[counter], {
            //         address: accts[counter],
            //         name: `Awesome Airline ${names[counter]}`,
            //         status: "UNKNOWN" // set as default state
            //     });
            //     this.airlines.push(accts[counter++]);
            // }

            // store details of the first pre-registered airline
            this.accountRoleMapping.set(accts[1], 'Airline');
            this.airlinesObjs.set(accts[1], {
                        address: accts[1],
                        name: `Awesome Airline One`,
                        status: "UNKNOWN" // set as default state
                    });
            this.airlines.push(accts[1]);
            
            // counter = 2;
            // while(this.passengers.length < 5) {
            //     this.accountRoleMapping.set(accts[counter], 'Passenger');
            //     this.passengers.push(accts[counter++]);
            // }

            // // airlines: 0 - 5
            // // passengers: 6 - 10
            // // oracle 11 - 30
            // // unassigned 31 - 50
            // this.unassignedAccounts = accts.slice(31, 36);

            // airlines: 1
            // unassigned 2 - 20
            this.unassignedAccounts = accts.slice(2, 20);

            // console.log(this.accountRoleMapping);


            // authorize app contract to call data contract
            this._authorizeDataContract((e, r)=> {
                console.log(e, r)
            });


            this.flightSuretyData.methods.isAuthorizedCaller(this.flightSuretyApp._address).call({from: self.owner}, (e, r)=>{
                console.log("is app contract authorized: ", r)
            });


            callback();
        });
    }

    async _authorizeDataContract(callback){
        console.log('attempting to auth app contract to access data contract')
        let self = this;
        var result = await self.flightSuretyData.methods
                .authorizeCaller(this.flightSuretyApp._address)
                .send({ from: self.owner}, callback);
        console.log("result from auth: ", result)
    }

    // set account to interact with contract as
    setWeb3ActiveAccount(account, callback) {
        this.activeAccount = account;
        console.log('got here. did my thing: ', this.activeAccount);
        callback();
    }
    
    getActiveWeb3Account(){
        return {address: this.activeAccount, role: this.accountRoleMapping.get(this.activeAccount)};
    }
    
    getWeb3AvailableAccounts(){
        return {airlines: this.airlines, passengers: this.passengers, owner: [this.owner], unassigned: this.unassignedAccounts}
    }

    // Airline related ops

    isParticipatingAirline(airline, callback) {
        let self = this;
        return self.flightSuretyData.methods
            .isParticipatingAirline(airline)
            .call({ from: self.owner}, callback);
    }

    isRegisteredAirline(airline, callback) {
        let self = this;
        return self.flightSuretyData.methods
            .isRegisteredAirline(airline)
            .call({ from: self.owner}, callback);
    }

    isCandidateAirline(airline, callback) {
        let self = this;
        return self.flightSuretyData.methods
            .isCandidateAirline(airline)
            .call({ from: self.owner}, callback);
    }

    registerAirline(airline, airlineName, callback) {
        console.log(`Contract regairline about to register  ${airline}, ${airlineName} acting as ${this.activeAccount}`);

        console.log('calling app contract to register ... ')
        // let self = this;
        // self.flightSuretyData.methods
        //         .registerAirline(airline, airlineName)
        //         .send({ from: self.owner}, (r, e)=>{
        //             console.log('resp from data contract: ', e, r)
        //         });

        let self = this;
        self.flightSuretyApp.methods
            .registerAirline(airline, airlineName)
            .send({from: self.activeAccount}, (err, result) => {
                console.log("Contract regairline post ..err: result ", err, result)
                if (!err) {
                    console.log("updating airline objs");
                    self.airlinesObjs.set(airline,
                        {
                            address: airline,
                            name: airlineName,
                            status: "PENDING_APPROVAL" // set as default state
                        }
                    );
                    self.airlines.push(airline);
                    
                }
                callback(err, result);
            })
        //     //.catch((x) => {console.log(x)})
    }


    approveAirline(airline, callback) {
        console.log(`Contract about to approve  ${airline}, acting as ${this.activeAccount}`);


        let self = this;
        self.flightSuretyApp.methods
            .approveAirline(airline)
            .send({from: self.activeAccount}, (err, result) => {
                console.log("Contract approval post ..err: result ", err, result)
                callback(err, result);
            })
    }

    
    async payRegistrationFee(callback) {
        let self = this;
        // automatically ask for the participation fee to the contract
        const fee = await self.flightSuretyApp.methods.AIRLINE_PARTICIPATION_FEE().call({from: self.owner});
        self.flightSuretyApp.methods
            .payAirlineParticipationFee()
            .send({from: self.activeAccount, value: fee}, (err, result)=>{
                if (!err) {
                    console.log("updating airline objs for pay reg ... ");
                    self.airlinesObjs.get(self.activeAccount).status = "PARTICIPATING"; 
                };
                callback(err, result);
            })        
    }

    getAirlineInfo(airlineAddress) {
        return this.airlinesObjs.get(airlineAddress);
    }

    getAirlinesObjects() {

        let self = this;

        self.airlines.forEach(function(account, _index){
            // console.log('iterator here now... ', account)

            self.isCandidateAirline(account, (e, r) => {
                if (r === true) {
                    self.airlinesObjs.get(account).status = "PENDING_APPROVAL";
                } else {
                    console.log(e);
                }
            });

            self.isRegisteredAirline(account, (e, r) => {
                if (r === true) {
                    self.airlinesObjs.get(account).status = "PENDING_PAYMENT";
                } else {
                    console.log(e);
                }
            });

            self.isParticipatingAirline(account, (e, r) => {
                if (r === true) {
                    self.airlinesObjs.get(account).status = "PARTICIPATING";
                    self.participatingAirlines.add(account);
                } else {
                    console.log(e);
                }
            });

        });

        // console.log('helpppppp: ', Array.from(self.airlinesObjs.values()));

        return Array.from(self.airlinesObjs.values());
    }

    // INSURANCE FUNCTIONS

    purchaseInsurance(flightId, airline, flightTimestamp, amountWei, callback) {
        console.log(`buying insurance with the details: id ${flightId} | airline ${airline} | ts: ${flightTimestamp} | amount: ${amountWei} | passenger: ${this.activeAccount}`)
        let self = this;
        self.flightSuretyApp.methods
            .purchaseInsurance(airline, flightId, flightTimestamp)
            .send({from: self.activeAccount, value: amountWei}, (error, result) => {
                console.log('buy response from contract ', error, result);
                callback(error, result);
            });
    }


    // getMetaskAccountID(callback) {
    //     // web3 = new web3(App.web3Provider);

    //     this.web3.eth.getAccounts(function(err, res) {
    //         callback(err, res);
    //     })
    //     // Retrieving accounts
    //     // this.web3.eth.getAccounts(function(err, res) {
    //     //     if (err) {
    //     //         console.log('Error:',err);
    //     //         return;
    //     //     }
    //     //     console.log('getMetaskID:',res);
    //     //     return res[0];
    //     //     // App.metamaskAccountID = res[0];
    //     //     //web3.eth.defaultAccount = web3.eth.accounts[0]; // used for default operations

    //     // });
    // }

    // Passenger Functions

    queryBalance(callback) {
        let self = this;
        self.flightSuretyApp.methods
            .fetchPassengerBalance()
            .call({from: this.activeAccount}, callback);
    }

    triggerWithdrawal(callback) {
        let previousBalance;
        this.web3.eth.getBalance(this.activeAccount, (e, r) =>{
            if (e) { console.log(e) };
            console.log(`Active account wallet balance before withdrawal: ${web3.utils.fromWei(r.toString(), "ether")} ETH` );
            previousBalance = web3.utils.fromWei(r.toString(), "ether");
        });
        
        let self = this;        
        self.flightSuretyApp.methods
            .processPassengerWithdrawal()
            .send({from: this.activeAccount}, (err, res)=>{
                let newBalance;
                self.web3.eth.getBalance(self.activeAccount, (e, r) =>{
                if(e){console.log(e)};
                console.log(`Active account wallet after withdrawal: ${web3.utils.fromWei(r.toString(), "ether")} ETH` );
                // newBalance = web3.utils.fromWei(r.toString(), "ether");
                // web3.utils.fromWei(r.toString(), "ether")
                newBalance = web3.utils.fromWei(r.toString(), "ether")
                const finalRes = `{${res} | Previous Balance: ${previousBalance} | New Balance: ${newBalance}}`;
                callback(err, finalRes)
                });
            //     const finalRes = `{${res} | Previous Balance: ${previousBalance} | New Balance: ${newBalance}}`;
            // callback(err, finalRes)
            }); 
    }    

    // Admin Function

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
    }

    fetchFlightStatus(flightNumber, flightTimestamp, airline, callback) {
        console.log(`request flight status for id ${flightNumber} | airline ${airline} | ts: ${flightTimestamp}`);
    
        let self = this; 
        self.flightSuretyApp.methods
            .fetchFlightStatus(airline, flightNumber, flightTimestamp)
            .send({ from: self.owner}, (error, result) => {
                callback(error, result);
            });
    }
}
