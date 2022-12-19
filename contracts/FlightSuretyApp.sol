pragma solidity ^0.8.0;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/utils/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    FlightSuretyData dataContract;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Airlines

    enum AirlineStatus {
        Candidate, // 0 - Pending approvals, not enough votes yet. Sitting in registration queue
        Registered, // 1 - Has required number of votes (approvals), pending payment of participation fees
        Participant // 2 - Has required number of votes (approvals) and has paid participation fees
    }

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;          // Account used to deploy contract

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;        
        address airline;
    }
    mapping(bytes32 => Flight) private flights;

    uint8 constant MIN_FOR_MULTIPARTY_CONSENSUS = 4; // multiparty concensus active only after these number of airlines are fully registered (i.e participating)
    uint256 constant AIRLINE_CONSENSUS_PERCENT = 50; // pecentage of participating airlines that must approve/vote to achieve consensus
    uint256 public constant AIRLINE_PARTICIPATION_FEE = 10 ether; // Fee airlines must pay after registration to become active participants
    uint256 public constant MIN_INSURANCE_AMOUNT_WEI = 1;
    uint256 public constant MAX_INSURANCE_AMOUNT_WEI = 1000000000000000000; // 1 ETH

 
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
         // Modify to call data contract's status
        require(true, "Contract is currently not operational");  
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

    modifier requireParticipatingAirline() {
        require(dataContract.isParticipatingAirline(msg.sender), "Only participating airlines are allowed to perform this operation!");
        _;
    }

    // modifier requireRegisteredAirline() {
    //     require(dataContract.isRegisteredAirline(msg.sender), "Address not in registration queue!");
    //     _;
    // }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor
                                (
                                    address dataContractAddress
                                ) 
                                public 
    {
        contractOwner = msg.sender;
        dataContract = FlightSuretyData(dataContractAddress);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() 
                            public view 
                            returns(bool) 
    {
        // return true;  // Modify to call data contract's status
        return dataContract.isOperational();
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  
   /**
    * @dev Add an airline to the registration queue
    *
    */   
    // function _registerAirlineOld
    //                         (
    //                             address airline,
    //                             string memory name
    //                         )
    //                         external
    //                         returns(bool success, uint256 votes)
    // {   
    //     require(!dataContract.isCandidateAirline(airline), "Airline is already in registration queue, please vote/approve instead!");
    //     require(!dataContract.isRegisteredAirline(airline), "Airline is already registered!"); // 
    //     require(!dataContract.isParticipatingAirline(airline), "Airline is already participating!");

    //     //  ensure only participating airlines can register airlines airlines until
    //     //  minimum requirement for multiparty threshold is reached
    //     uint256 participatingAirlines = dataContract.getParticipatingAirlineCount();
    //     if (participatingAirlines < MIN_FOR_MULTIPARTY_CONSENSUS) {
    //         require(dataContract.isParticipatingAirline(msg.sender), "Only participating airlines can register for now.");
    //     }
        

    //     AirlineStatus status = AirlineStatus.Candidate;
    //     votes = 0; 
    //     uint requiredNumberOfApprovals = 10; // @todo calculate 50% of participating airlines


    //     // CASE A - Registration submitted by an participating airline
    //     if (dataContract.isParticipatingAirline(msg.sender)) {
    //         votes = 1;
    //         dataContract.recordApprovalVote(msg.sender, airline);
    //     }

    //     // CASE B - No concensus required
    //     if (participatingAirlines < MIN_FOR_MULTIPARTY_CONSENSUS) {
    //         status = AirlineStatus.Registered;
    //         votes = requiredNumberOfApprovals; // auto approve, give required no of votes
    //     }


    //     dataContract.registerAirline(airline, name, uint(status));

    //     return (true, votes);
    // }

    /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline
                            (
                                address airline,
                                string memory name
                            )
                            external
                            returns(bool success, uint256 votes)
    {   
        require(!dataContract.isCandidateAirline(airline), "Airline is already in registration queue, please vote/approve instead!");
        require(!dataContract.isRegisteredAirline(airline), "Airline is already registered!"); // 
        require(!dataContract.isParticipatingAirline(airline), "Airline is already participating!");

        //  ensure only participating airlines can register airlines airlines until
        //  minimum requirement for multiparty threshold is reached
        uint256 participatingAirlines = dataContract.getParticipatingAirlineCount();
        if (participatingAirlines < MIN_FOR_MULTIPARTY_CONSENSUS) {
            require(dataContract.isParticipatingAirline(msg.sender), "Only participating airlines can register for now.");
        }
        
        // register airline
        dataContract.registerAirline(airline, name);

        // if the airline is registered by an already participating airline
        // the registration should count as an approval by the participating airline
        if (dataContract.isParticipatingAirline(msg.sender)){
            votes = processAirlineApproval(airline, msg.sender);
        }

        return (true, votes);
    }

    
    /**
    * @dev Approve an airline in the registration queue
    *
    */   
    function processAirlineApproval
                            (
                                address airline,
                                address approver
                            )
                            internal
                            // requireParticipatingAirline
                            // canVoteOnlyOnce
                            returns(uint256 votes)
    {   

        uint256 participatingAirlineCount = dataContract.getParticipatingAirlineCount();
        uint256 requiredVotes;


        if (participatingAirlineCount < MIN_FOR_MULTIPARTY_CONSENSUS) {
           requiredVotes = 1;
        } else {
            requiredVotes = participatingAirlineCount.mul(AIRLINE_CONSENSUS_PERCENT).div(100);
        }

        
        // retrieve current votes for airline
        uint256 airlineVotes = dataContract.getAirlineApprovalVotesCount(airline);
        airlineVotes++;

        if (airlineVotes >= requiredVotes) {
            // CASE A: condition to register the airline has been satisfied
            dataContract.setAirlineAsRegistered(airline);
            // emit airline registered event
        } else {
            // CASE B: not enough votes/approvals to move to registered
            // record vote and wait for the next vote instead
            dataContract.recordAirlineApprovalVote(approver, airline);
        }

        return  airlineVotes;

    }



    /**
    * @dev Approve an airline in the registration queue
    *
    */   
    function approveAirline
                            (
                                address airline
                            )
                            external
                            requireParticipatingAirline
                            returns(bool success, uint256 votes)
    {   

        // uint256 participatingAirlineCount = dataContract.getParticipatingAirlineCount();
        // uint requiredVotes = participatingAirlineCount.mul(AIRLINE_CONSENSUS_PERCENT).div(100);
        
        // // retrieve current votes for airline
        // uint256 airlineVotes = dataContract.getAirlineApprovalVotesCount(airline);
        // AirlineStatus status = AirlineStatus.Candidate;

        // airlineVotes++;

        // if (airlineVotes >= requiredVotes) { // required approval threshold has been reached
        //     status = AirlineStatus.Registered;
        //     dataContract.updateAirlineStatus(airline, status);
        //     // emit airline registered event here
        // } else {
        //     dataContract.recordApprovalVote(msg.sender, airline);
        // }

        // return (true, airlineVotes);

        require(!dataContract.hasPreviouslyVoted(airline, msg.sender), "You have already approved this airline.");

        votes = processAirlineApproval(airline, msg.sender);
        success = true;
        // return (success, votes); should be added by compiler
    }


    /**
    * @dev Approve an airline in the registration queue
    *
    */ 
    function payAirlineParticipationFee() external payable 
                            requireIsOperational
    {   
        require(!dataContract.isCandidateAirline(msg.sender), "Airline registration hasn't be approved yet.");
        require(!dataContract.isParticipatingAirline(msg.sender), "Airline has already paid the participation fee.");
        require(dataContract.isRegisteredAirline(msg.sender), "Airline must be registered before paying the participation fee.");
        require(msg.value >= AIRLINE_PARTICIPATION_FEE, "Funds does not cover the required to participation fee!");

        dataContract.fund{ value: AIRLINE_PARTICIPATION_FEE }();
        dataContract.setAirlineAsParticipant(msg.sender);  
        // @todo emit event here      
        
    }


   /**
    * @dev Register a future flight for insuring.
    *
    */  
    function registerFlight
                                (
                                )
                                external
                                pure
    {

    }

   /**
    * @dev Purchase a flight insurance.
    *
    */  
    function purchaseInsurance
                                (
                                    address airline,
                                    string memory flight,
                                    uint256 timestamp
                                )
                                requireIsOperational
                                external
                                payable
    {

        require(!dataContract.isInsured(msg.sender, airline, flight, timestamp), "Passenger is already insured for this flight!");
        require(msg.value >= MIN_INSURANCE_AMOUNT_WEI && msg.value <= MAX_INSURANCE_AMOUNT_WEI, "Invalid insurance amount.");
    
        uint256 payoutAmountWei = SafeMath.div(SafeMath.mul(msg.value, 15), 10);
        
        dataContract.buy(msg.sender, airline, flight, timestamp, msg.value, payoutAmountWei);

    }

   /**
    * @dev fetch active insurance .
    *
    */  
    function listPassengerInsurance
                                (
                                )
                                external
                                pure
    {

    }

   /**
    * @dev returns passenger contract wallet balance. Insurance payouts go to the passenger's contract wallet not directly to their ETH account.
    *
    */  
    function fetchPassengerBalance
                                (
                                )
                                requireIsOperational
                                external
                                view
                                returns (uint256)
    {
        return dataContract.getPassengerBalance(msg.sender);
    }


   /**
    * @dev passenger withdrawal -- triggers a transfer of acured insurance payments from passenger's contract wallet to their ETH account
    *
    */  
    function processPassengerWithdrawal
                                (
                                )
                                requireIsOperational
                                external
                                returns (bool)
    {   
        dataContract.pay(msg.sender);
        return true;
    }
    
   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus
                                (
                                    address airline,
                                    string memory flight,
                                    uint256 timestamp,
                                    uint8 statusCode
                                )
                                internal
    {   

        if (statusCode == uint8(STATUS_CODE_LATE_AIRLINE)) {
            dataContract.creditInsurees(airline, flight, timestamp);
        } else {
            dataContract.denyInsurees(airline, flight, timestamp);
        }
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp                            
                        )
                        requireIsOperational
                        external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
    } 


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;
    // Group oracle responses by code
    mapping(bytes32 => mapping(uint => address[])) private oracleResponseByCode;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;
        // mapping in structs now depracated in sol 0.8.0  // If open, oracle responses are accepted
        // mapping(uint8 => address[]) responses;         // Mapping key is the status code reported
                                                         // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    function isOracleAlreadyRegistered() external view returns (bool) {
        return oracles[msg.sender].isRegistered;
    }

    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");
        require(!oracles[msg.sender].isRegistered, "Already registered!... ");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }


    function isOracleRequestOpenForIndex(address airline, string memory flight, uint256 timestamp, uint8 index) external view 
                                        requireIsOperational
                                        returns(bool) 
    {
        // uint8 index,
        // address airline,
        // string memory flight,
        // uint256 timestamp,
        // uint8 statusCode
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 

        return oracleResponses[key].isOpen;
        // bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        // address empty;
        // require(oracleResponses[key].requester != empty, "undefined request found");
        // return oracleResponses[key].isOpen;
    }


    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3] memory)
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string memory flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Oracle response for flight is now closed.");

        oracleResponseByCode[key][statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponseByCode[key][statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);

            // Close further responses
            oracleResponses[key].isOpen = false;
        }
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
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3] memory)
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}   


interface FlightSuretyData { 
    enum AirlineStatus {
        Candidate,  // 0 - Pending approvals, not enough votes yet. Sitting in registration queue
        Registered, // 1 - Has required number of votes (approvals), pending payment of participation fees
        Participant // 2 - Has required number of votes (approvals) and has paid participation fees
    }


    function isOperational() external view 
                        returns(bool);

    // Airlines

    //  ---- modifiers

    function isParticipatingAirline(address airline) external view
                                returns (bool);

    function isRegisteredAirline(address airline) external view                
                                returns (bool);


    function isCandidateAirline(address airline) external view                    
                                returns (bool);


    // ---- state altering functions

    function registerAirline(address airline, string memory airlineName) external;

    function setAirlineAsRegistered(address airline) external;

    function setAirlineAsParticipant(address airline) external;

    function recordAirlineApprovalVote(address approver, address airline) external returns (uint256 votes);

    function getAirlineApprovalVotesCount(address airline) external returns (uint256 votes);


    // function addCandidateAirline(address airline, string memory airlineName, address fromVoter) external;
                                


    // function removeCandidateAirline(address airline) external;
                                    


    // votes 

    function addCandidateAirlineVote(address airline, address fromVoter) external returns (uint256);
    function hasPreviouslyVoted(address candidateAirline, address approvingAirline) external view returns (bool);



    // fees
    function recordAirlineParticipationFee(address airline) external;
                                            


    // Insurance 
    function buy(address passenger, address airline, string memory flight, uint256 timestamp,  uint256 insuranceAmountWei, uint256 payoutAmountWei) external payable;

    function pay(address passenger) external; 

    function creditInsurees(address airline, string memory flight, uint256 timestamp) external;

    function denyInsurees(address airline, string memory flight, uint256 timestamp) external;
                            
    // function updateInsuranceStatus(address airline, string memory flight, uint256 timestamp, InsuranceStatus status) external;

    function isInsured(address passenger, address airline, string memory flight, uint256 timestamp) external view returns(bool);
    

    // wallets
    function getPassengerBalance (address passenger) view external returns (uint256);

    // Flights 

    function getFlightStatus(address airline, string memory flight, uint256 timestamp) external view returns(uint8);


    function recordFlightStatus(address airline, string memory flight, uint256 timestamp, uint8 statusCode) external;
                            

    // utils

    function getParticipatingAirlineCount() external view returns (uint256);

    function getCandidateAirlineName(address airline) external view returns(string memory); 

    //
    function fund() external payable;
}