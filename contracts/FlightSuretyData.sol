pragma solidity ^0.8.0;

import "../node_modules/openzeppelin-solidity/contracts/utils/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                              // Account used to deploy contract
    bool private operational = true;                            // Blocks all state changes throughout the contract if false
    mapping(address => bool) private authorizedCallers;         // To store App contract (and other) addresses that are authorized to access this data contract

    enum AirlineStatus {
        _Default,       // to prevent empty enum being initialized to `Candidate`. Zero value of an enum is picked by default when initializing.
        Candidate,      // 0
        Registered,     // 1
        Participant     // 2
    }

    struct Airline {
        address airlineAddress;
        string name;
        AirlineStatus status; 
    }

    struct AirlineApprovalVote {
        uint256 count;
        mapping(address => bool) voters;
    }

    enum InsuranceStatus {
        _DEFAULT,   // to prevent empty enum being initialized to `PURCHASED`. Zero value of an enum is picked by default when initializing.
        PURCHASED,  // 0
        DENIED,     // 1
        PAID        // 2
    }

    struct Insurance {
        uint256 amount; // insurance amount paid by passenger
        uint256 payout; // payout amount based on insurance 
        bytes32 flightKey;
        address passenger;
        InsuranceStatus status; // tricky to update when stored together with the struct
    }

    /********************************************************************************************/
    /*                                           ENTITIES                                       */
    /********************************************************************************************/

    mapping(address => Airline) airlines;
    address[] airlineAddresses; // useful to keep count of addresses and iterate over "airlines" mapping
    uint256 participatingAirlinesCount = 0;

    mapping(address => AirlineApprovalVote) private approvalVotes;

    mapping(address => uint256) private passengerWalletBalances;

    // mapping(bytes32 => Insurance[]) flightInsurance; // flight key to array of insurances for the flight. Used for payouts

    // mapping(address => bytes32[]) passengerInsurances

    // mapping(address => Insurance[]) passengerInsurance; // mapping of passengers to their insurance

    // mapping(byte32 => address[]) flightInsuredPassengers; // list of passengers with insurance for a flight

    /// take 3 
    /// db[passenger][flightkey] ==> Insurance

    /// flight key => [passengers] (used to iterate while paying out insurance gain)
    /// passenger => [flight keys] (used to load insurances for a particular user)

    mapping(address => mapping(bytes32 => Insurance)) flightInsurance; // all flight insurance

    mapping(bytes32 => address[]) flightInsuredPassengers; // get list of passengers that purchased insurance for a flight using the flight key.

    mapping(address => bytes32[]) passengerInsuredFlights; // get list of flights a passenger purchased insurance for using the passenger address.

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                    address firstAirline, string memory firstAirlineName
                                ) 
                                public 
    {
        contractOwner = msg.sender;
        
        authorizedCallers[contractOwner] = true;
        
        // register first (default) airline, better in the data contract
        // so a new airline doesn't need to be registred each time a new app
        // contract is deployed
        airlines[firstAirline] = Airline(
            firstAirline,
            firstAirlineName,
            AirlineStatus.Registered
        );
        
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireAuthorizedCaller()
    {
        require(authorizedCallers[msg.sender], "Caller is not authorized.");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }

    function isAuthorizedCaller(address possibleCaller) 
                            public 
                            view 
                            returns(bool) 
    {
        return authorizedCallers[possibleCaller];
    }

    function authorizeCaller(address caller) 
                            requireIsOperational 
                            requireAuthorizedCaller
                            public 
                            returns(bool) 
    {
        authorizedCallers[caller] = true;
        return authorizedCallers[caller];
    }



    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline
                            (   
                                address airlineAddress,
                                string memory airlineName
                            )
                            requireIsOperational
                            requireAuthorizedCaller
                            external
    {
        airlines[airlineAddress] = Airline(
            airlineAddress,
            airlineName,
            AirlineStatus.Candidate
        );
    }

    function setAirlineAsRegistered(address airline) requireIsOperational requireAuthorizedCaller external {
        airlines[airline].status = AirlineStatus.Registered;
    }

    function setAirlineAsParticipant(address airline) requireIsOperational requireAuthorizedCaller external {
        airlines[airline].status = AirlineStatus.Participant;
        participatingAirlinesCount++;
    }

    function isCandidateAirline(address airline) view external returns (bool)
    {
        return airlines[airline].status == AirlineStatus.Candidate;
    }

    function isRegisteredAirline(address airline) view external returns (bool)
    {
        return airlines[airline].status == AirlineStatus.Registered;
    }

    function isParticipatingAirline(address airline) view external returns (bool)
    {
        return airlines[airline].status == AirlineStatus.Participant;
    }

    function isAirline(address airline) view external returns (bool) {
        return airlines[airline].airlineAddress == airline;
    }

    function getParticipatingAirlineCount() view external returns (uint256)
    {
        return participatingAirlinesCount;
    }

    function hasPreviouslyVoted(address candidateAirline, address approvingAirline) external view returns (bool){
        return approvalVotes[candidateAirline].voters[approvingAirline];
    }

    function recordAirlineApprovalVote(address approver, address airline) requireIsOperational requireAuthorizedCaller external returns (uint votes) {
        approvalVotes[airline].voters[approver] = true;
        approvalVotes[airline].count++;
        votes = approvalVotes[airline].count;
    }

    function getAirlineApprovalVotesCount(address airline) requireAuthorizedCaller external view returns (uint256 votes) {
        return approvalVotes[airline].count;
    }

   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (
                               address passenger, address airline, string memory flight, uint256 timestamp,  uint256 insuranceAmountWei, uint256 payoutAmountWei                            
                            )
                            requireIsOperational
                            requireAuthorizedCaller
                            external
                            payable
    {

        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        

        // struct Insurance {
        //     uint256 amount; // insurance amount paid by passenger
        //     uint256 payout; // payout amount based on insurance 
        //     bytes32 flightKey;
        //     address passenger;
        //     InsuranceStatus status; // tricky to update when stored together with the struct
        // }
        
        //  mapping(address => mapping(bytes32 => Insurance))
        //     mapping(address => mapping(bytes32 => Insurance)) flightInsurance; // all flight insurance
        // Insurance memory inc = Insurance(
        //     insuranceAmountWei,
        //     payoutAmountWei,
        //     flightKey,
        //     passenger,
        //     InsuranceStatus.PURCHASED
        // );
        // flightInsurance[passenger][flightKey];
        // flightInsurance[passenger][flightKey] = inc;
        flightInsurance[passenger][flightKey] = Insurance(
            insuranceAmountWei, // insurance amount paid by passenger
            payoutAmountWei, // payout amount based on insurance 
            flightKey,
            passenger,
            InsuranceStatus.PURCHASED
        );

        

        // mapping(bytes32 => address[]) flightInsuredPassengers; // get list of passengers that purchased insurance for a flight using the flight key.
        flightInsuredPassengers[flightKey].push(passenger);

        // mapping(address => bytes32[]) passengerInsuredFlights;
        passengerInsuredFlights[passenger].push(flightKey);

    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                    address airline, string memory flight, uint256 timestamp
                                )
                                requireIsOperational
                                requireAuthorizedCaller
                                external
    {   
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        address passenger; 
        for(uint256 i = 0; i < flightInsuredPassengers[flightKey].length; i++) {
            passenger = flightInsuredPassengers[flightKey][i];
            flightInsurance[passenger][flightKey].status = InsuranceStatus.PAID;
            passengerWalletBalances[passenger] = SafeMath.add(
                passengerWalletBalances[passenger], flightInsurance[passenger][flightKey].payout
                );  
        }
    }


    /**
     *  @dev Deny payouts to insurees. To be called by the app contract when it has determined condition for payout is not met.
    */
    function denyInsurees
                                (
                                    address airline, string memory flight, uint256 timestamp
                                )
                                requireIsOperational
                                requireAuthorizedCaller
                                external
    {   
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        address passenger; 
        for(uint256 i = 0; i < flightInsuredPassengers[flightKey].length; i++) {
            passenger = flightInsuredPassengers[flightKey][i];
            flightInsurance[passenger][flightKey].status = InsuranceStatus.DENIED;
            passengerWalletBalances[passenger] = SafeMath.add(
                passengerWalletBalances[passenger], flightInsurance[passenger][flightKey].payout
                );  
        }
    }

    function isInsured(address passenger, address airline, string memory flight, uint256 timestamp) requireAuthorizedCaller external view returns(bool){
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        return flightInsurance[passenger][flightKey].passenger == passenger;
    } 

    function getPassengerBalance (address passenger) view external returns (uint256) {
        return passengerWalletBalances[passenger];
    }

    // function fetchPassengerInsurance (address passenger) external returns (Insurance[] memory) {
    //     Insurance[] storage res;
    //     for(uint256 i = 0; i < passengerInsuredFlights[passenger].length; i++) {
    //         bytes32 flightKey = passengerInsuredFlights[passenger][i];
    //         res.push(flightInsurance[passenger][flightKey]);
    //         passengerWalletBalances[passenger] = SafeMath.add(
    //             passengerWalletBalances[passenger], flightInsurance[passenger][flightKey].payout
    //             );  
    //     }
    // }

    // /**
    //  *  @dev Credits payouts to insurees
    // */
    // function updateInsuranceStatus
    //                             (
    //                                 address airline, string memory flight, uint256 timestamp, InsuranceStatus status
    //                             )
    //                             external
    // {
    //     bytes32 flightKey = getFlightKey(airline, flight, timestamp);

    //     //Opportunity for Improvement
    //     // Problem:  As the size of the data increases, the gas required to successfully complete the loop can potetially become
    //     //           greater than the block gas limit. This means that the loop while start failing. 
    //     // Solution: A possible solution would be to support dynamic start and end index. i.e the start and end index can be passed 
    //     //           as arguments to the function through a function call. This will allow to batch up the loops and avoid
    //     //           exceeding the block gas limit.

    //     for(uint256 i = 0; i < flightInsuredPassengers[flightKey].length; i++) {
    //         flightInsurance[flightInsuredPassengers[flightKey][i]][flightKey].status = status;      
    //     }
    // }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                                address passenger
                            )
                            requireIsOperational
                            requireAuthorizedCaller
                            external
    {
        // reset the balance for the passenger
        uint256 balance = passengerWalletBalances[passenger];
        passengerWalletBalances[passenger] = 0;
        payable(passenger).transfer(balance);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            (   
                            )
                            public
                            payable
                            requireIsOperational
                            requireAuthorizedCaller
    {
    }

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
        // bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    fallback() 
                            external 
                            payable 
    {
        fund();
    }


}

