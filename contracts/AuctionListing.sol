pragma solidity ^0.5.0;

import "./IAuctionListing.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Secondary.sol";

/**
* @title AuctionEscrow
* @dev Base auction listing contract, holds funds designated for a payee until they
* withdraw them and performs all the functions needed to carry out an auction. Contract Conditional
* contains state variables and function modifiers.
* @dev Intended usage: This contract is a
* standalone contract that only interacts with the contract that instantiated
* it.
*/
contract AuctionListing is Secondary, IAuctionListing {
    using SafeMath for uint256;

    /***********************************|
    |             Events                |
    |__________________________________*/   
    event ListingBuilt(
        address indexed listingAddress, 
        bool groupable, 
        address payable winner,
        uint64 ltMax,
        uint64 creationTime,
        uint64 auctionTime,
        uint64 endTime,
        uint64 revealTime,
        uint64 minMerit,
        uint256 maxPrice,
        uint32 fPBid,
        string productURI
    ); 
    event revealMade (address indexed listing, address indexed revealee, uint256 unencryptedBid, uint256 refund);
    event refundMade (address indexed listing, address indexed refundee, uint256 refund);
    event winnerUpdated (address indexed listing, address indexed winner);
    event invalidBid (address indexed listing, address indexed bidder, uint256 unencryptedBid);
    /***********************************|
    |             Storage               |
    |__________________________________*/

    // provavelmente retirar e passar metadata para offchain ou isto passar a representar um apontador para IPFS (ipfs.io)
    string private productURI;
    
    struct ListingData {
        bool canceled;
        bool groupable;
        bool hasSuppliers;
        address payable winner;
        uint32 fPBid;
        uint64 ltMax;
        uint64 creationTime;
        uint64 auctionTime;
        uint64 endTime;
        uint64 revealTime;
        uint64 minMerit;
        uint256 quantity;
        uint256 maxPrice;
        uint256 highestBid;
    }
    
    //decide if adding depositedWei here, or doing the calculation via quantity times max price or leading bid.
    struct Client {
        uint256 weiAmount;
        uint256 quantity;
        uint256 index;
        address transporter;
        bool isParticipating;
        bool canWithdraw;
        uint64 deliveryStartTime;
        uint64 inputKeyTTime;
        uint64 distributionLeadTime;
        bytes32 publicSKey;
    }

    struct Supplier {
        uint256 weiAmount;
        bytes32 encryptedBid;
        bool isParticipating;
    }
    
    ListingData private lData;

    // key : client , value : Client Struct
    mapping (address => Client) private clientParams;
    // key : supplier , value : Supplier Struct
    mapping (address => Supplier) private supplierParams;
    
    address[] private clients;
    address[] private suppliers;

    /***********************************|
    |             Modifiers             |
    |__________________________________*/

    modifier onlyAfterListingStart {
        require (block.timestamp >= uint256(lData.creationTime),"Time is before listing creation");
        _;
    }

    modifier onlyBeforeAuctionStart {
        require (block.timestamp < uint256(lData.auctionTime),"Time is past the auction start");
        _;
    }
    
    modifier onlyAfterAuctionStart {
        require (block.timestamp >= uint256(lData.auctionTime),"Time is before the auction start");
        _;
    }

    modifier onlyBeforeAuctionEnd {
        require (block.timestamp < uint256(lData.endTime),"Time is past the auction end");
        _;
    }

    modifier onlyAfterAuctionEnd {
        require (block.timestamp >= uint256(lData.endTime),"Time is not past the auction end");
        _;
    }

    modifier onlyBeforeRevealEnd {
        require (block.timestamp < uint256(lData.revealTime),"Time is past the reveal end");
        _;
    }

    modifier onlyAfterRevealEnd {
        require (block.timestamp >= uint256(lData.revealTime),"Time is not past reveal end");
        _;
    }

    modifier onlyRevealEndOrCanceled {
        require(
            block.timestamp >= uint256(lData.revealTime) || lData.canceled, "Time is not past reveal end, or the auction has not been canceled");
        _;
    }

    modifier onlyNotCanceled {
        require (!lData.canceled,"The listing was canceled");
        _;
    }
    
    modifier onlyCanceled {
        require (lData.canceled,"The listing was not canceled yet");
        _;
    }

    modifier onlyCorrectPayments (uint256 _quantity) {
        require (msg.value == lData.maxPrice.mul(_quantity) && msg.value > 10,"The amount in wei is not correct or is below 10 wei");
        _;
    }
    
    modifier onlyValidMerit (uint64 _merit) {
        require(lData.minMerit <= _merit, "The participant does not have the required rating to join the listing");
        _;
    }
    
    modifier onlyJoinableListings ()
    {
        require(
            lData.groupable || (!lData.groupable && clients.length == 0), "This listing is not joinable");
        _;
    }

        
    modifier onlyActiveListings ()
    {
        (uint256 quantityToFulfil,) = getQuantities();

        require( quantityToFulfil != 0, "This listing is not active anymore as it doesn't have buyers");
        _;
    }

    modifier onlyClient (address _participant)
    {
        require (clientParams[_participant].isParticipating, "The candidate is not participating or is a supplier");
        _;
    }

    modifier onlySupplier (address _participant)
    {
        require (supplierParams[_participant].isParticipating, "The address is not a participating supplier or is a buyer");
        _;
    }
    
    modifier onlyNonClient (address _participant)
    {
        require (!clientParams[_participant].isParticipating, "The address is already a candidate in the listing");
        _;
    }

    modifier onlyNonSupplier (address _participant)
    {
        require(!supplierParams[_participant].isParticipating,"The address is already a supplier in the listing");
        _;
    }

    modifier onlyWinner (address _bidder)
    {
        require (_bidder == lData.winner, "The bidder is not the auction winner");
        _;
    }

    modifier onlyNonWinner (address _bidder)
    {
        require (_bidder != lData.winner, "The bidder is the auction winner");
        _;
    }

    modifier onlyCorrectTransporter (address _client, address _transporter)
    {
        require (clientParams[_client].transporter == _transporter, "The address is not the transporter to the given client");
        _;
    }

    modifier onlyClientOrSupplier (address _participant)
    {
        require((supplierParams[_participant].isParticipating && !clientParams[_participant].isParticipating) ||
        (!supplierParams[_participant].isParticipating && clientParams[_participant].isParticipating), "The address is not participating");
        _;
    }

    modifier onlyWithMinParticipation ()
    {
        require(clients.length-1 > 0, "Requires a minimum of 1 clients in the listing");
        _;
    }

    //To be removed in actual deployment
    modifier onlyAfterHashT(address _client)
    {
        require(block.timestamp>=clientParams[_client].inputKeyTTime, "Key has been input before the transporter has performed his function");
        _;
    }

    /***********************************|
    |             Functions             |
    |__________________________________*/

    /**
    * @dev Initialises the contract listing with static information. ltMin and minRating are optional parameters and if set as 0 they are not taken into consideration
    * @param _uri The product identificator
    * @param _groupable Whether the proposal can be syndicated or not
    * @param _ltMax The listing maximum lead time
    * @param _timePacked Listing timer packed
    * @param _minMerit The minimum supplier merit to participate in this listing
    * @param _maxPrice The maximum price to be paid by each participant
    * @param _fPBid The percentage of total listing value to be paid to the platform
    */
    constructor (
        string memory _uri,
        bool _groupable,
        uint64 _ltMax,
        uint256 _timePacked,
        uint64 _minMerit,
        uint256 _maxPrice,
        uint32 _fPBid)
        public 
    {
        uint64 _creationTime = uint64(_timePacked);
        uint64 _auctionTime = uint64(_timePacked >> 64);
        uint64 _endTime = uint64(_timePacked >> 128);
        uint64 _revealTime = uint64(_timePacked >> 192);

        //Time validation
        require(_creationTime <= _auctionTime,"Creation time must be after auction launch time");
        require(_auctionTime <= _endTime, "Auction start time must be before auction end time");
        require(_endTime <= _revealTime, "Auction end time must be before end time");
        require(_creationTime >= block.timestamp, "Creation time can't be in the past");

        productURI =  _uri;
        

        
        ListingData memory ld = ListingData ({
            canceled: false,
            groupable: _groupable,
            hasSuppliers: false,
            winner: address(0),
            ltMax: _ltMax,
            creationTime: _creationTime,
            auctionTime: _auctionTime,
            endTime: _endTime,
            revealTime: _revealTime,
            minMerit: _minMerit,
            quantity: 0,
            maxPrice: _maxPrice,
            highestBid: _maxPrice,
            fPBid: _fPBid
        });
        lData = ld;

        emit ListingBuilt(
            address(this), 
            ld.groupable,
            ld.winner,
            ld.ltMax, 
            ld.creationTime, 
            ld.auctionTime,
            ld.endTime,
            ld.revealTime,
            ld.minMerit,
            ld.maxPrice,
            ld.fPBid,
            productURI
        ); 

    }

    /**
    * @dev Adds a new client to the Listing
    * @param _participant The address of the client
    * @param _quantity The client's desired quantity
    */
    function pushClient (
        address _participant, 
        uint256 _quantity 
        ) 
        external
        onlyPrimary
        onlyAfterListingStart
        onlyBeforeAuctionStart
        onlyNotCanceled
        onlyJoinableListings
        onlyCorrectPayments(_quantity)
        onlyNonClient (_participant)
        payable
    {
        clients.push(_participant);
        Client memory c;
        c.weiAmount = msg.value;
        c.quantity = _quantity;
        c.index = clients.length-1;
        c.isParticipating = true;
        c.canWithdraw = false;
        clientParams[_participant] = c;

        (uint256 quantityToFulfil, uint256 totalQuantity) = getQuantities();
        _setQuantities(quantityToFulfil.add(_quantity), totalQuantity.add(_quantity));
    }

    /**
    * @dev Removes participation in a listing for a potential client
    * @param _client The client whose participation is to be canceled
    */
    function cancelClient (
        address payable _client) 
        external 
        onlyPrimary
        onlyAfterListingStart
        onlyBeforeAuctionStart
        onlyNotCanceled
        onlyClient(_client)
        returns (uint256)
    {
        uint256 payment = clientParams[_client].weiAmount;
        require(payment > 0 , "There is nothing to withdraw");

        (uint256 quantityToFulfil, uint256 totalQuantity) = getQuantities();
        _setQuantities(quantityToFulfil.sub(clientParams[_client].quantity), totalQuantity.sub(clientParams[_client].quantity));
        
        clientParams[_client].weiAmount = 0; 
        clientParams[_client].quantity = 0;
        clientParams[_client].isParticipating = false;
        _burnBuyer(clientParams[_client].index);
        _client.transfer(payment);
        return payment;
    }

    function _burnBuyer(uint _index) internal {
        uint256 len = clients.length;
        require(_index < len, "Client cannot be burned at an index beyond array length");
        clients[_index] = clients[len-1];
        delete clients[len-1];
        clients.length--;
    }

    /**
    * @dev Adds a new supplier to the Listing with a valid bid
    * @param _participant The address of the supplier
    * @param _encryptedBid The desired (encrypted) bid value
    * @param _merit The merit of the supplier
    */
    function pushSupplier (
        address _participant, 
        bytes32 _encryptedBid, 
        uint64 _merit) 
        external
        onlyPrimary
        onlyAfterAuctionStart
        onlyBeforeAuctionEnd
        onlyNotCanceled
        onlyActiveListings
        onlyNonSupplier (_participant)
        onlyValidMerit (_merit)
        payable
    {

        suppliers.push(_participant);
        supplierParams[_participant] = Supplier(msg.value, _encryptedBid, true);
        
        if(!lData.hasSuppliers) {
            lData.hasSuppliers = true;
        }
    }

    /**
    * @dev Function to reveal the encrypted bids and set the auction winner
    * @notice Will only be callable at the end of the reveal period
    * @param _participant The revealing supplier
    * @param _unencryptedBid The unencrypted bid
    */
    function revealBid (address payable _participant, uint256 _unencryptedBid, uint256 _nonce) 
        external
        onlyPrimary 
        onlySupplier(_participant)
        onlyBeforeRevealEnd
        onlyAfterAuctionEnd
        onlyNotCanceled
        onlyActiveListings
    {
        require(supplierParams[_participant].encryptedBid == keccak256(abi.encodePacked(_unencryptedBid, _nonce)),
        "The bid was incorrectly revealed or it has already been revealed, reverting.");

        uint256 refund = supplierParams[_participant].weiAmount;
        supplierParams[_participant].weiAmount = 0;
        supplierParams[_participant].encryptedBid = bytes32(0);
        
        if (_unencryptedBid > lData.maxPrice) {
            // invalid bid -> force value return
            _participant.transfer(refund);
            emit invalidBid (address(this), _participant, _unencryptedBid);
            return;
        }
        (, uint256 totalQuantity) = getQuantities();

        bool updateSuccess = _updateWinner(_participant, _unencryptedBid, totalQuantity);

        
        if (updateSuccess) {
            refund -= (_unencryptedBid*totalQuantity*uint256(lData.fPBid))/100;
        }

        _participant.transfer(refund);

        emit revealMade (address(this), _participant, _unencryptedBid, refund);
     
    }

    /**
    * @dev Internal function to update the auction winner
    * @param bidder The revealing supplier
    * @param value The unencrypted bid
    */
    function _updateWinner(address payable bidder, uint256 value, uint256 totalQuantity) internal returns (bool)
    {
        //reveal will be done on a first-come basis. Hence the "higher than or equal" check
        //suppliers are penalized if they reveal late (same bid as another participant who has already revealed)
        if (value >= lData.highestBid && lData.winner != address(0)) {
            return false;
        }
        if (lData.winner != address(0)) {
            // Refund the previously highest bidder.
            lData.winner.transfer((lData.highestBid*totalQuantity*uint256(lData.fPBid))/100);
            emit refundMade(address(this), lData.winner, supplierParams[lData.winner].weiAmount);
        }
        lData.highestBid = value;
        lData.winner = bidder;
        emit winnerUpdated(address(this), bidder);
        return true;
    }

    /**
    * @dev Initiates the delivery for a given client saving the block height and transporter address
    * @notice *WIP* - NOT FINAL
    * @param _winner The address of the supplier
    * @param _client The address of the client
    * @param _transporter The address of the transporter
    * @param _publicSKey The cryptographic hash of the key given to the transporter
    */    
    function initiateDelivery (address _winner, address _client, address _transporter, bytes32 _publicSKey) 
        external 
        onlyPrimary
        onlyAfterRevealEnd
        onlyWinner(_winner)
        onlyClient(_client)
        onlyActiveListings
    {
        clientParams[_client].deliveryStartTime = uint64(block.timestamp);
        clientParams[_client].transporter = _transporter;
        clientParams[_client].publicSKey = _publicSKey;
    }

   /**
    * @dev Client inputs the received shipment key from the transporter
    * @notice *WIP* - NOT FINAL
    * @param _client The address of the client
    * @param _privateSKey The shipment key
    */  
    function keyVerification (address _client, bytes32 _privateSKey) 
        external
        onlyPrimary
        onlyAfterRevealEnd
        onlyClient(_client)
        onlyActiveListings
        returns (bool, uint256, address)
    {
        bool verified = false;
        
        if (clientParams[_client].publicSKey == keccak256(abi.encodePacked(_privateSKey)))
        {
            verified = true;

            uint256 supplierPayment = clientParams[_client].quantity.mul(lData.highestBid);

            clientParams[_client].weiAmount = clientParams[_client].weiAmount.sub(supplierPayment);

            supplierParams[lData.winner].weiAmount = supplierParams[lData.winner].weiAmount.add(supplierPayment);

            clientParams[_client].canWithdraw = true;

            (uint256 quantityToFulfil, uint256 totalQuantity) = getQuantities();

            _setQuantities(quantityToFulfil.sub(clientParams[_client].quantity), totalQuantity);

            uint256 nowTime = block.timestamp;

            uint256 leadTime = nowTime.sub(uint256(clientParams[_client].deliveryStartTime));

            clientParams[_client].distributionLeadTime = uint64(leadTime);

            return (
                verified, 
                 (leadTime.mul(1000)).div(uint256(lData.ltMax)), 
                lData.winner
            );
        }
        else
        {
            //transfer funds to a mediator contract as well as with all the addresses - input mediator address
            return (false, 1001, lData.winner);
        }
    }

    /*
    * @dev Transporter can use this function after 60 blocks since input of the keys and the buyer has not entered their keys. Enters in mediation
    * @notice *WIP* - NOT FINAL - DEACTIVATED
    * @param _client The address of the client
    * @param _transporter The address of the transporter
    *
    function clientExceededBlockLimit (address _client, address _transporter)
        external
        onlyPrimary
        onlyFulfilmentPhase
        onlyClient(_client)
        onlyCorrectTransporter(_client, _transporter)
    {
        require(block.number > uint256(clientParams[_client].inputKeyTBlock) + 60, "The block limit was not exceeded yet (currently 60 blocks)");
        require(clientParams[_client].hashT.length > 0, "The transporter's hash is empty");
        require(!clientParams[_client].canWithdraw, "The client has already called their own function and activated withdrawals");
        //transfer client's funds to mediator
    }
*/

    /**
    * @dev Manual withdraw function (can only be used if auction is canceled or terminated)
    * @param _beneficiary The address of the withdraw beneficiary
    */
    function withdraw(address payable _beneficiary)
        external
        onlyPrimary
        onlyRevealEndOrCanceled
        onlyClientOrSupplier (_beneficiary)
        returns (uint256)
    {
        uint256 withdrawalAmount = 0;
        bool client = false;
        bool supplier = false;

        //If the beneficiary is a client
        if (clientParams[_beneficiary].isParticipating)
        {
            client = true;
        //If the beneficiary is the winner
        }else if (supplierParams[_beneficiary].isParticipating)
        {
            supplier = true;
        }
        
        if (lData.canceled) 
        {
                withdrawalAmount = clientParams[_beneficiary].weiAmount;
        } else 
        {
            if (supplier) 
            {
                withdrawalAmount = supplierParams[_beneficiary].weiAmount;
            } 
            // removed clientParams[_beneficiary].canWithdraw before deplyement
            // since this would only get activated in keyVerification which is disabled
            else if (client )
            {
                withdrawalAmount = clientParams[_beneficiary].weiAmount;
            }
        }

        require(withdrawalAmount > 0, "There is nothing to withdraw");
        require(_beneficiary != address(0), "No withdrawal account selected");
        
        if (supplier)
        {
            supplierParams[_beneficiary].weiAmount = 0;
            supplierParams[_beneficiary].isParticipating = false;
        } else if (client)
        {
            clientParams[_beneficiary].weiAmount = 0;
            clientParams[_beneficiary].isParticipating = false;
            // disabled for now
            // clientParams[_beneficiary].canWithdraw = false;
        }

        // send the funds
        _beneficiary.transfer(withdrawalAmount);

        return withdrawalAmount;
    }
   
    /**
    * @dev Cancels the auction, marking canceled = true, impeding access to the contract main functions and allowing for withdrawal of escrow deposits by all clients
    */
    function cancelAuction()
        external
        onlyPrimary
        onlyBeforeAuctionEnd
    {
        lData.canceled = true;
    } 

    /**
    * @dev Compacts the total quantity left to fulfil and the total quantity ordered
    */
    function _setQuantities(uint256 _quantityToFulfil, uint256 _totalQuantity) internal {
        lData.quantity = _quantityToFulfil;
        lData.quantity |= _totalQuantity << 128;

    }

    /**
    * @dev Gets the same quantities as before
    */
    function getQuantities() public view returns (uint256, uint256) {
        return (
            uint256(uint128(lData.quantity)), //quantityToFulfil
            uint256(uint128(lData.quantity>>128)) //totalQuantity
        );
    }

    /**
    * @dev Returns listing max price
    */
    function getMaxPrice () 
        external 
        view
        returns (uint256)
    {
        return lData.maxPrice;
    }

    /**
    * @dev Returns listing winner
    */
    function getWinner () 
        external 
        view
        returns (address)
    {
        return lData.winner;
    }

    /**
    * @dev Returns auction end time
    */
    function getEndTime () 
        external 
        view
        returns (uint256)
    {
        return uint256(lData.endTime);
    }

    /**
    * @dev Returns clients array
    */
    function getListingData () 
        external 
        view
        returns (
        bool,
        bool,
        bool,
        address,
        uint64,
        uint64,
        uint64,
        uint64,
        uint64,
        uint64,
        uint256,
        uint256
        )
    {
        return (
        lData.canceled,
        lData.groupable,
        lData.hasSuppliers,
        lData.winner,
        lData.ltMax,
        lData.creationTime,
        lData.auctionTime,
        lData.endTime,
        lData.revealTime,
        lData.minMerit,
        lData.maxPrice,
        lData.highestBid
        );
    }

    function getListingURI () external view returns (string memory) {
        return productURI;
    }

    /**
    * @dev Returns clients array
    */
    function getClients () 
        external 
        view
        returns (address[] memory)
    {
        return clients;
    }


    function getClientData (address _client) 
    external
    view
    returns(
        uint256,
        uint256,
        uint64,
        uint64,
        uint64,
        address,
        bool
    ) {
        return (
        clientParams[_client].weiAmount,
        clientParams[_client].quantity,
        clientParams[_client].deliveryStartTime,
        clientParams[_client].inputKeyTTime,
        clientParams[_client].distributionLeadTime,
        clientParams[_client].transporter,
        clientParams[_client].canWithdraw
        );
    }

    /**
    * @dev Returns suppliers array
    */
    function getSuppliers () 
        external 
        view
        returns (address[] memory)
    {
        return suppliers;
    }

    function getSupplierData (address _supplier) 
    external
    view
    returns(
        address,
        uint256,
        bytes32,
        bool,
        bool,
        bool,
        bool
    ) {
        bool bid = false;
        bool revealed = false;
        bool canWithdraw = false;

        if(supplierParams[_supplier].encryptedBid == bytes32(0) &&  supplierParams[_supplier].isParticipating) {
            revealed = true;
        } else if(supplierParams[_supplier].encryptedBid != bytes32(0) &&  supplierParams[_supplier].isParticipating) {
            bid = true;
        }

        if(block.timestamp >= lData.revealTime && supplierParams[_supplier].weiAmount > 0 &&
        (lData.winner == _supplier || supplierParams[_supplier].encryptedBid != bytes32(0))) {
            canWithdraw = true;
        }

        return (
        _supplier,
        supplierParams[_supplier].weiAmount,
        supplierParams[_supplier].encryptedBid,
        supplierParams[_supplier].isParticipating,
        bid,
        revealed,
        canWithdraw
        );
    }

    function isClientParticipating (address _client)
    external
    view
    returns(
        bool
    ) {
        return (
            clientParams[_client].isParticipating);
    }

    function isSupplierParticipating (address _supplier)
    external
    view
    returns(
        bool
    ) {
        return (
            supplierParams[_supplier].isParticipating);
    }

    function listingIsJoinable ()
    external
    view
    returns(
        bool
    ) {
        return (
            (lData.groupable || (!lData.groupable && clients.length == 0)) && 
            (block.timestamp >= lData.creationTime && block.timestamp < lData.auctionTime)
        );
    }

    function isRevealPeriodOver () 
    external
    view
    returns (
        bool
    ){
        return block.timestamp >= lData.revealTime;
    }

    function getFPBid ()
    external
    view
    returns (
        uint32
    ) {
        return lData.fPBid;
    }
}