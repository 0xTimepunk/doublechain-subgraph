pragma solidity ^0.5.0;

import "./AuctionListing.sol";
import "./ListingInteraction.sol";

/**
* @title ListingFactory
* @dev ListingFactory contract that is instantiated once for the entire lifetime of the dapp
* (unless upgraded). 
* @dev Intended usage: The contract allows for the instantiation of new AuctionListing
* contracts with given parameters. Generating these contracts through this primary contract binds
* the created AuctionListing to this contract's address and only allowing transactions to occur through
* it.
*/
contract ListingFactory {
    using SafeMath for uint256;

    /***********************************|
    |             Events                |
    |__________________________________*/

    //Events when interacting with the Listing's instances
    event ListingProduced(address indexed listingAddress, address indexed creator); 
    
    /***********************************|
    |             Storage               |
    |__________________________________*/

    // key : Auction Listing , value : user
    mapping (address => address) public createdBy;

    address[] private listingAddresses;
    address payable private listingInteractionContract;
    address payable private feeCollector;
    uint256 revealTime;
    /***********************************|
    |             Modifiers             |
    |__________________________________*/

    modifier onlyWhitelistAdmin (address payable _interactionContract) {
        require(ListingInteraction(_interactionContract).isWhitelistAdmin(msg.sender),"The user is not an admin on the factory");
        _;
    }

    modifier onlyAuthListingCreators() {
        require(ListingInteraction(listingInteractionContract).isClient(msg.sender)||
        ListingInteraction(listingInteractionContract).isSupplier(msg.sender), "Not an authorized creator");
        _;
    }

    /***********************************|
    |             Functions             |
    |__________________________________*/

    constructor (address payable _interactionContract, address payable _feeCollector) public onlyWhitelistAdmin(_interactionContract) {
        listingInteractionContract = _interactionContract;
        feeCollector = _feeCollector;
        revealTime = 180;
    }

    function setListingInteractionContract (address payable _interactionContract) external onlyWhitelistAdmin(_interactionContract) {
        listingInteractionContract = _interactionContract;
    }


    function setRevealTime (uint256 _revealTime) external onlyWhitelistAdmin(listingInteractionContract) {
        revealTime = _revealTime;
    }

    /**
    * @dev Creates a listing with static data without participants.
    * @param _uri The product identificator
    * @param _groupable Whether the proposal can be syndicated or not
    * @param _ltMax The listing maximum lead time
    * @param _creationTime Listing creation time
    * @param _auctionTime Auction start time
    * @param _endTime End of the auction time
    * @param _minMerit The minimum supplier merit to participate in this listing
    * @param _maxPrice The maximum price to be paid by each participant
    */
    function newListing (
        string calldata _uri,
        bool _groupable,
        uint64 _ltMax,
        uint256 _creationTime, 
        uint256 _auctionTime, 
        uint256 _endTime,
        uint64 _minMerit,
        uint256 _maxPrice
        ) 
        external
        onlyAuthListingCreators
        payable
    {
        (uint256 fList, uint32 fPBid) = ListingInteraction(listingInteractionContract).getFeeSchedule();

        require(_maxPrice > 10, "The intended max price must be bigger than 10 Wei to allow the percentual fee calculation and for clients to enter (and at least one bid)");
        require(msg.value == fList, "The function caller must transfer 1 finney as fee for the creation");
        uint256 timePacked = _creationTime;
        timePacked |= _auctionTime << 64;
        timePacked |= _endTime << 128;
        timePacked |= (revealTime + _endTime) << 192;

        //Creates a new auction listing contract (with basic information)
        AuctionListing listing = new AuctionListing(
            _uri,
            _groupable,
            _ltMax,
            timePacked,
            _minMerit,
            _maxPrice,
            fPBid
        );

        listingAddresses.push(address(listing));
        createdBy[address(listing)]= msg.sender;
        AuctionListing(listing).transferPrimary(listingInteractionContract);
        feeCollector.transfer(msg.value);

        emit ListingProduced(address(listing),msg.sender);
    }

    /**
    * @dev This function gets the number of listings created
    */
    function getListingsCount() external view returns (uint256){
        return listingAddresses.length;
    }

    /**
    * @dev This function gets the addresses of listings created
    */
    function getListingAddresses() external view returns (address[] memory){
        return listingAddresses;
    }

    /**
    * @dev This function gets a specific listing creator
    */
    function getListingCreator(address _listing) external view returns (address){
        return createdBy[_listing];
    }
}
