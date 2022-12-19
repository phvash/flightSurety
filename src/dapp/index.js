
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';
import Web3 from 'web3';


var App = {

    Utils: {
        generateFlights: function(contract) {

            const flightCountPerAirline = 2;

            // let airlines = contract.getAirlinesObjects();
            // console.log('airline in gen flight ', airlines);
            let flightsList = new Map();


            contract.participatingAirlines.forEach(function(airlineAddress, _index){
                console.log('airliine from deep in the loop .. ', airline);
                // if (airline.status == "PARTICIPATING"){
                let flightCount = 1;

                console.log("found participating airline, generating flight for ", airline);

                let airline = contract.airlinesObjs.get(airlineAddress);

                while (flightCount <= flightCountPerAirline) {
                    // generate  mock future flight
                    let randomNo = Math.floor(Math.random() * (1000 - 100) + 100);
                    let flightDetails = {
                        id: `${airline.address}-${randomNo}`,
                        number: `${randomNo}`,
                        airline: airline.address,
                        airlineName: airline.name,
                        timestamp: Date.now() + (1800000 * flightCount), // now but increment 30 mins for reach flight added
                    }
                    
                    // flightsList.push(flightDetails);
                    flightsList.set(flightDetails.id, flightDetails)
                    flightCount++;
                };
                // };
                contract.availableFlights = flightsList;
            });

            // return flightsList
            return Array.from(flightsList.values());
        }
    }

};

var UIUpdateFunctions = {
    updateWeb3AccountList: function(contract){
        console.log("nohting crazy")
        // <option>1</option>
        let accounts = contract.getWeb3AvailableAccounts()
        console.log(accounts);

        let accountOptions = DOM.elid("activeAccountInputOptions");

        accounts.airlines.forEach(function(account, _index){
            accountOptions.append(new Option(`Airline ${_index + 1} [${account}]`))
        });

        accounts.passengers.forEach(function(passenger, _index){
            accountOptions.append(new Option(`Passenger ${_index + 1} [${passenger}]`))
        });

        accounts.unassigned.forEach(function(addr, _index){
            accountOptions.append(new Option(`Unassigned ${_index + 1} [${addr}]`))
        });

    },

    updateFlightList: function(contract){
        // @todo retrieve from oracle API endpoint
        // let flights = [
        //     {
        //         id: '001A',
        //         airlineAddress: contract.airlines[0],
        //         airlineName: 'Awesome Airline One'
        //     },
        //     {
        //         id: '001B',
        //         airlineAddress: contract.airlines[0],
        //         airlineName: 'Awesome Airline One'
        //     },
        //     {
        //         id: '002A',
        //         airlineAddress: contract.airlines[1],
        //         airlineName: 'Awesome Airline Two'
        //     },
        // ]

        let flights = App.Utils.generateFlights(contract);

        console.log("generated mock flights: ", flights);

        let flightOptions = DOM.elid("insureFlightInputOptions");

        flightOptions.innerHTML = '';

        flights.forEach(function(flight){
            // flightOptions.append(new Option(`${flight.id} | [${flight.airlineName}] - ${new Date(flight.timestamp).toLocaleString("en-US")}`))
            flightOptions.append(new Option(`${flight.id} | [${flight.airlineName}] - ${new Date(flight.timestamp).toLocaleString("en-US")}`))
        });

    },

    updateAvailableFlightList: function(contract){
        // @todo retrieve from oracle API endpoint
        // 

        let flights = contract.insuredFlights;

        // let flights = contract.insuredFlightsMap;

        console.log('insured flights available ', flights);

        let insurableflightoptions = DOM.elid("flightInputOptions");

        insurableflightoptions.innerHTML = '';

        flights.forEach(function(flight){
            insurableflightoptions.append(new Option(`${flight}`));
        });

    },

    updateActiveWeb3Account: function(contract){
        
        let activeAccount = contract.getActiveWeb3Account();

        console.log('activeAccount: ', activeAccount);

        DOM.elid("activeWeb3Account").value = activeAccount.address;
        DOM.elid("activeWeb3AccountRole").value = activeAccount.role;

        // other places
        
        // DOM.elid("myAirlineAddress").value = activeAccount.address;
        DOM.elid("myAirlineRegAddress").value = activeAccount.address;


    },

    updateAirlineStatus: function(contract){
        
        let status = "UNKNOWN";
        let airline = contract.getAirlineInfo(contract.activeAccount);

        if (airline) {status = airline.status};

        console.log('airline: ', airline);

        DOM.elid("myAirlineAddress").value = contract.activeAccount;
        DOM.elid("myAirlineApprovalStatus").value = status;

    },

    updateAirlineList: function(contract){
        let airlines = contract.getAirlinesObjects();
        let airlineList = DOM.elid("listAirlines");
        airlineList.innerHTML = '';

        airlines.forEach(function(airline, _index){
            airlineList.appendChild(DOM.li(`${airline.name} [${airline.address}] - ${airline.status}]`));
        });
    },

    updateAirlineDetails: function(contract){
        // this.updateAirlineStatus
        // let airline = contract.getAirlineInfo(contract.activeAccount);
    },

    displayContractResponse: function(err, result){
        if (err) {
            alert(err);
        } else {
            alert(`Success: ${result}`)
        };
    },

    alertUser: function(msg){
        alert(msg);
    },

    displayAirlineForFlight: function(){
        console.log('something happened: ...');
        let flightOptions = DOM.elid("insureFlightInputOptions");
 
        let selectedFlightOption = flightOptions.options[flightOptions.selectedIndex];
        if (!selectedFlightOption){
            return
        };
        selectedFlightOption = selectedFlightOption.value;
       
        // sample value for selectedAccountOption is "Airline 1 [0x018C2daBef4904ECbd7118350A0c54DbeaE3549A]"
       
        let flightId = selectedFlightOption.split('|')[0].trim();
        let airlineAddress = flightId.split('-')[0];
        let airlineName = selectedFlightOption.slice(
            selectedFlightOption.indexOf('[') + 1,
            selectedFlightOption.indexOf(']')
        );
        DOM.elid("selectedFlightAirlineName").value = airlineName;
        DOM.elid("selectedFlightAirlineAddress").value = airlineAddress;
    }
};

var ButtonHandlers = {
    registerOtherAirlineBtn: function (contract) {

        const address = DOM.elid('regOthersAirlineAddress').value;
        const name =  DOM.elid('regOthersAirlineName').value;

        console.log(address, name);

        contract.registerAirline(address, name, (err, result) => {
            // if (err) {
            //    UIUpdateFunctions.alertUser(err);
            // }

            UIUpdateFunctions.displayContractResponse(err, result);

            // refresh status after the operation
            // refreshAirlineLists(contract);
        })
    },

    // registerSelfAirlineBtn: function (contract) {
    //     // event.preventDefault(); // cancel default behavior

    //     const address = contract.activeAccount; // get current user's address
    //     const name =  DOM.elid('regSelfAirlineName').value;
        
    //     contract.registerAirline(address, name, (err, result) => {
    //         if (err) {
    //             UIUpdateFunctions.alertUser(err);
    //         }

    //         // refresh status after the operation
    //         // refreshAirlineLists(contract);
    //     })
    // },

    // refreshApprovalStatusBtn: function () {
    //     // event.preventDefault(); // cancel default behavior

    //     // UIUpdateFunctions.updateAirlineStatus(contract);
    // },

    payRegFeeBtn: function (contract) {
        // event.preventDefault(); // cancel default behavior
        // self = this;
        contract.payRegistrationFee((e, r)=>{
            // UIUpdateFunctions.updateAirlineStatus(contract);
            UIUpdateFunctions.displayContractResponse(e, r)
        }
            );
    },

    buyInsuranceBtn: function (contract) {

        // retrieve selected flight 
        let flightOptions = DOM.elid('insureFlightInputOptions');

        let selectedFlightEl = flightOptions.options[flightOptions.selectedIndex];

        if(!selectedFlightEl){
            alert('Please select a flight. You can use the "Refresh Flights" button to generate new flights');
            return
        };

        let selectedFlightOption = selectedFlightEl.value;
        
       
        // sample value for selectedAccountOption is "Airline 1 [0x018C2daBef4904ECbd7118350A0c54DbeaE3549A]"
       
        let flightId = selectedFlightOption.split('|')[0].trim();
        let flight = contract.availableFlights.get(flightId);

        let amount =  DOM.elid('insuranceAmount').value;

        // add validation check
        let floatAmount = parseFloat(amount);
        if (!floatAmount || floatAmount <= 0 || floatAmount > 1.0 ) {
            alert(`Amount "${amount}" ETH is invalid. Expects value between 0 and 1.0.`);
            return;
        }

        let amountWei = Web3.utils.toBN(Web3.utils.toWei(amount, "ether"));
        
        // flightId, airline, flightTimestamp, amountWei, callback
        contract.purchaseInsurance(flight.number, flight.airline, flight.timestamp, amountWei, (error, result)=>{
            if (!error){
                contract.insuredFlights.push(flight.id);
                contract.insuredFlightsMap.set(flight.id, flight);
            };
            UIUpdateFunctions.displayContractResponse(error, result);
            UIUpdateFunctions.updateAvailableFlightList(contract);
        });
    },

    refreshAvailableFlightstBtn: function(contract) {
        UIUpdateFunctions.updateFlightList(contract);
    },

    triggerWithdrawalBtn: function (contract) {
        contract.triggerWithdrawal(UIUpdateFunctions.displayContractResponse);
    },

    checkBalanceBtn: function (contract) {
        contract.queryBalance((error, result)=>{
            if (result) {
                let balance = Web3.utils.fromWei(result.toString(), "ether");
                DOM.elid("availableBalance").value = balance;
            };
            
            UIUpdateFunctions.displayContractResponse(error, result);
        });
    },

    updateFlightStatusBtn: function (contract) {
        
        // retrieve selected flight 
        let flightOptions = DOM.elid('flightInputOptions');
        let selectedFlightOption = flightOptions.options[flightOptions.selectedIndex].value;

        let flight = contract.insuredFlightsMap.get(selectedFlightOption);

        if (!flight) {
            alert("Flight not found!");
            return
        }

        // flightNumber, flightTimestamp, airline

        contract.fetchFlightStatus(flight.number, flight.timestamp, flight.airline, (error, result)=>{
            if (!error) {
                result = "Successfully triggered. Please monitor Oracle Server logs.";
            };

            UIUpdateFunctions.displayContractResponse(error, result);
        });

        // const address = ''; // get current user's address
        // const amount =  DOM.elid('withdrawalAmount').value;

        // var status = App.updateFlightStatus();
 
    },

    // registerFlightBtn: function () {

    //     // const address = ''; // get current user's address
    //     // const amount =  DOM.elid('withdrawalAmount').value;

    //     console.log("register flight");

    //     // var status = App.updateFlightStatus();
    // },

    approveAirlineBtn: function (contract) {

        const address = DOM.elid('airlineToApproveAddress').value;

        contract.approveAirline(address, (err, result) => {
            // if (err) {
            //    UIUpdateFunctions.alertUser(err);
            // }

            // refresh status after the operation
            // refreshAirlineLists(contract);
            // if (result) {
            //     // update airlines list
            // }
            UIUpdateFunctions.displayContractResponse(err, result);
        })
    },

    refreshAirlinesListBtn: function (contract) {
        UIUpdateFunctions.updateAirlineList(contract);
    },

    updateWeb3AccountBtn: function (contract) {
        const accountOptions = DOM.elid('activeAccountInputOptions');
        const selectedAccountOption = accountOptions.options[accountOptions.selectedIndex].value;
       
        // sample value for selectedAccountOption is "Airline 1 [0x018C2daBef4904ECbd7118350A0c54DbeaE3549A]"
       
        const addr = selectedAccountOption.slice(
            selectedAccountOption.indexOf('[') + 1,
            selectedAccountOption.indexOf(']')
        );

        console.log('updating web3 account to: ', addr);
        
        contract.setWeb3ActiveAccount(addr, (err, result) => {
            console.log("Error updating web3 account: ", err)
            UIUpdateFunctions.updateActiveWeb3Account(contract);
        });
    }
};


(async() => {


    let contract = new Contract('localhost', async () => {

            // register handlers

        Object.entries(ButtonHandlers).forEach(entry => {
            const [btn, handler] = entry;
            DOM.elid(btn).addEventListener('click', () => {handler(contract)});
        });

        //
        DOM.elid('insureFlightInputOptions').addEventListener('change', UIUpdateFunctions.displayAirlineForFlight);

        // DOM.elid('insureFlightInputOptions').addEventListener('change', alert('fuck off!'));

        // Read transaction
        contract.isOperational((error, result) => {
            console.log('error: ', error)
            console.log("Contract is operational?: ", result)          
        });

        // update UI with valid data
        UIUpdateFunctions.updateWeb3AccountList(contract);
        UIUpdateFunctions.updateAvailableFlightList(contract);
        UIUpdateFunctions.updateFlightList(contract);
        UIUpdateFunctions.updateActiveWeb3Account(contract);
        UIUpdateFunctions.updateAirlineList(contract);


       
    
    });

})();

