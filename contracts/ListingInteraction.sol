pragma solidity ^0.5.0;

//implement interface of tracking token?
import "./Tokens/Tracking/ERC1155/TrackingToken.sol";
import "./IAuctionListing.sol";
import "./ListingRoles.sol";

/**
* @title ListingInteraction
* @dev ListingInteraction contract that is instantiated once for the entire lifetime of the dapp (unless upgraded). 
* @dev Intended usage: The contract allows registered users to interact with an Auction Listing via its functions
*/
contract ListingInteraction is ListingRoles {
    using SafeMath for uint256;

    /***********************************|
    |             Events                |
    |__________________________________*/

    event NewBuyer(address indexed listingAddress, address indexed buyer, uint256 depositedWei, uint256 quantity);
    event LeftListing(address indexed listingAddress, address indexed buyer, uint256 returnedWei);
    event SupplierJoined(address indexed listingAddress, address indexed supplier, uint256 depositedWei, bytes32 encryptedBid);
    event LogWithdrawal(address indexed listingAddress, address indexed withdrawalAccount, uint256 returnedWei);
    event LogCanceled(address indexed listingAddress);
    event NewShipment (address indexed listingAddress, address from, address to, address transporter);
    event ProofAdded (uint256 indexed tokenId, uint256 proofIndex);
    event NewKeyTInput (address indexed listingAddress, address transporter, address buyer);
    event SuccessfulDelivery (address indexed listingAddress, address buyer);
    event RejectedDelivery (address indexed listingAddress, address mediator);

    /***********************************|
    |             Storage               |
    |__________________________________*/

    address payable public feeCollector;
    address public trackingToken;

    struct fees{
        uint256 fList;
        uint32 fPBid;
    }

    fees public feeSchedule;
    
    enum ProvenanceStatus {TokenDistributed,InTransit,Fulfilled}
    
    // Mapping from listing address to token distribution status
    mapping(address => bool) tokensDistributed;

    // Mapping from NFToken ID to provenance status
    mapping(uint256 => ProvenanceStatus) listingProvenance;

    // Mapping from NFToken ID to proof. The Proof array for every token must include one or more items.
    mapping(uint256 => string[]) idToProof;

    /***********************************|
    |             Modifiers             |
    |__________________________________*/

    modifier onlyShippingMode (uint256 _tokenID) {
        require(uint256(listingProvenance[_tokenID]) == 1, "Not in transit mode");
        _;
    }

    modifier onlyWinner (address _listing) {
        require(IAuctionListing(_listing).getWinner() == msg.sender, "Not the listing winner");
        _;
    }

    /***********************************|
    |             Functions             |
    |__________________________________*/

    constructor (address payable _feeCollector, address _trackingToken) public {
        feeCollector = _feeCollector;
        //transfer primary to this contract after deployment
        trackingToken = _trackingToken;
        feeSchedule = fees(1000000000000000, 10);
    }

    /**
    * @dev Set the fee schedule
    * @dev fList = 1 finney; fBlindAuc = 1 szabo; fBid refers to a percentage
    * @param _fList The listing creation fee
    * @param _fPBid The supplier percentual bid fee
    */
    function setFeeSchedule (uint256 _fList, uint32 _fPBid) external onlyWhitelistAdmin {
        require(_fPBid < 101, "Bid fee must be equal or lower to 100%");
        feeSchedule = fees(_fList, _fPBid);
    }

    /**
    * @dev Gets the fee schedule
    */
    function getFeeSchedule () public view returns (uint256, uint32) {
        return (feeSchedule.fList, feeSchedule.fPBid);
    }

    /**
    * @dev Change the fee collector to a new address in case of a contract upgrade
    * @param _feeCollector The address of the fee collector
    */
    function setAuthFeeCollector (address payable _feeCollector) external onlyWhitelistAdmin {
        feeCollector = _feeCollector;
    }

    /**
    * @dev Change the token contract to a new address in case of an upgrade
    * @param _trackingToken The address of the token contract
    */
    function setTrackingTokenAddress (address  _trackingToken) external onlyWhitelistAdmin {
        trackingToken = _trackingToken;
    }

    /**
    * @dev Calls the pushBuyer function in a given listing. Msg.sender is automatically pushed as buyer and needs to deposit 100% of the value in escrow
    * @dev Anyone joining through this function cannot join again as a buyer or in auction phase as a supplier (with the same address)
    * @param _listing The address of the listing
    * @param _quantity The desired quantity to be bought
    */
    function joinListingAsBuyer (address _listing, uint256 _quantity) external onlyBuyer payable{
        IAuctionListing(_listing).pushBuyer.value(msg.value)(msg.sender,_quantity);

        emit NewBuyer (_listing, msg.sender, msg.value, _quantity);
    }

    /**
    * @dev Calls the cancelBuyer function in a given listing
    * @dev Currently the address can cancel the participation as a buyer and later join as a supplier
    * @param _listing The address of the listing
    */
    function cancelBuyerParticipation (address _listing) external onlyBuyer {
        uint256 payment = IAuctionListing(_listing).cancelBuyer(msg.sender);

        emit LeftListing (_listing, msg.sender, payment);
    }

    /**
    * @dev Calls the pushSupplier function in a given listing. 
    * @notice WARNING - Currently allowing 0 bids. This might change in the future. Supplier still pays a variable fee according to the listing value (see below)
    * @notice Msg.sender is automatically pushed as a supplier. The same address cannot be a buyer in the listing
    * @notice All participating suppliers deposit a fee comprised of a % of the max listing value + a fee to allow for a blind auction
    * @notice The true bid value is sent encrypted. At the end of the auction, each participant must reveal their encrypted bid
    * @notice The winner will be determined during the reveal time
    * @notice All losing suppliers can withdraw their deposited fees following reveal
    * @param _listing The address of the listing
    * @param _encryptedBid The supplier's encrypted bid
    */
    function joinListingAsSupplier (address _listing, bytes32 _encryptedBid) external onlySupplier payable{      
        (uint256 quantityToFulfil,)= IAuctionListing(_listing).getQuantities();
        require (msg.value == (uint256(feeSchedule.fPBid)*quantityToFulfil*IAuctionListing(_listing).getMaxPrice())/100, 
        "Incorrect amount transfered, reverted");

        uint64 repScore = _getTotalReputationScore();

        IAuctionListing(_listing).pushSupplier.value(msg.value)(msg.sender, _encryptedBid, repScore);

        emit SupplierJoined (_listing, msg.sender, msg.value, _encryptedBid);
    }

    /**
    * @dev Reveal your blinded bids. 
    * @notice You will get a refund for all
    * @notice correctly blinded invalid bids and for all bids except for
    * @notice the totally highest.
    * @param _listing The address of the listing
    * @param _unencryptedBid The supplier's un-encrypted bid
    * @param _nonce The original nonce sent with the bid
    */
    function revealBid (address _listing, uint256 _unencryptedBid, uint256 _nonce) external onlySupplier{      
        IAuctionListing(_listing).revealBid(msg.sender, _unencryptedBid, _nonce);

    }

    /**
    * @dev Function to be called by the platform to distribute the provenance tokens once the winner is determined
    * @param _listing The address of the listing
    */
    function distributeProvenanceTokens (address _listing) external onlyWinner(_listing) {
        require (IAuctionListing(_listing).isRevealPeriodOver(), "Not in fulfilment mode");
        require (tokensDistributed[_listing] == false, "Tokens have already been distributed");

        string memory uri = IAuctionListing(_listing).getListingURI();
        address[] memory buyers = IAuctionListing(_listing).getBuyers();

        // changed mintNonFungible to public - careful. 
        // a better option to consider is to modify the mint function
        // with the listing modifiers

        uint256 typeID;

        typeID = TrackingToken(trackingToken).create(uri, true);

        TrackingToken(trackingToken).mintNonFungible(typeID, buyers);

        tokensDistributed[_listing] = true;
    }

    /**
    * @dev Calls the initiateDelivery function in a given listing and mints a token representing a product
    * @notice Private and public shipment key must be generated off-chain and kept as a secret to all the parties.
    * @param _listing The address of the listing
    * @param _buyer The address of the buyer
    * @param _transporter The address of the transporter
    * @param _publicSKey The public shipment key (hashed version of the key that verifies the end of the shipping process)
    * @param _tokenID The identifier of the buyer token
    */    
    function initiateDelivery (address _listing, address _buyer, address _transporter, bytes32 _publicSKey, uint256 _tokenID) external onlySupplier {
        require(isTransporter(_transporter), "The intended transporter must be registered first");
        require(tokensDistributed[_listing] = true, "Tokens have not been distributed");
        require(TrackingToken(trackingToken).isNonFungibleItem(_tokenID) , "The token is not a NFT" );
        require(TrackingToken(trackingToken).ownerOf(_tokenID) == _buyer, "The buyer has not received a token");

        IAuctionListing(_listing).initiateDelivery(msg.sender,_buyer,_transporter,_publicSKey);

        listingProvenance[_tokenID] = ProvenanceStatus(1);

        emit NewShipment (_listing, msg.sender, _buyer, _transporter);     
    }

    /**
    * @dev Adds new proof to chain of proofs for the token
    * @param _tokenID Id of token that we want to add proof to
    * @param _proof New proof we want to add
    */
    function chain(uint256 _tokenID, string calldata _proof) external onlyTransporter onlyShippingMode(_tokenID)  {
        require(bytes(_proof).length > 0);
        require(TrackingToken(trackingToken).isNonFungible(_tokenID));

        idToProof[_tokenID].push(_proof);

        emit ProofAdded(_tokenID, idToProof[_tokenID].length.sub(1));
    }

    /**
    * @dev Gets proof by index.
    * @param _tokenID Id of the token we want to get proof of
    * @param _index Index of the proof we want to get.
    */
    function getTokenProofByIndex(uint256 _tokenID, uint256 _index) external view returns (string memory){
        require(_index < idToProof[_tokenID].length);
        return idToProof[_tokenID][_index];
    }

    /**
    * @dev Gets the count of all proofs for a token
    * @param _tokenID Id of the token we want to get the count from
    */
    function getTokenProofCount(uint256 _tokenID) external view returns (uint256){
        return idToProof[_tokenID].length;
    }

    /**
    * @dev Calls the key verification function in a given listing
    * @param _listing The address of the listing
    * @param _privateSKey The private key to unlock the shipment
    * @param _tokenID The ID of the token representing the shipment
    */    
    function keyVerification (address _listing, bytes32 _privateSKey, uint256 _tokenID) external onlyBuyer onlyShippingMode(_tokenID)  {
        (bool verified, uint256 lTPercent,address winner) = IAuctionListing(_listing).keyVerification(msg.sender,_privateSKey);
        
        if (verified){
            uint64 repGiven;
            if (lTPercent <= 250){
                repGiven = 8;
            } else if (lTPercent > 250 && lTPercent <= 500) {
                repGiven = 6;
            } else if (lTPercent > 500 && lTPercent <= 750) {
                repGiven = 4;
            } else if (lTPercent > 750 && lTPercent <= 1000) {
                repGiven = 2;
            }

            if (repGiven > 0) {
                _createReputation(winner, repGiven);
            }

            listingProvenance[_tokenID] = ProvenanceStatus(2);

            emit SuccessfulDelivery (_listing, msg.sender);

        } else {
            emit RejectedDelivery (_listing, msg.sender);
        }

    }

    /**
    * @dev Withdraws the funds in escrow if the listing has been canceled or has ended, both for buyers and winning supplier
    * @param _listing The address of the listing
    */
    function withdrawFunds (address _listing) external onlyAuthWithdrawees{
        uint256 withdrawalAmount = IAuctionListing(_listing).withdraw(msg.sender);

        emit LogWithdrawal(_listing,msg.sender, withdrawalAmount);
    }

    /**
    * @dev Cancels the auction at a specific address. Allows withdrawal for participating buyers
    * @param _listing The address of the listing
    */
    function cancelListing (address _listing) external onlyWhitelistAdmin{
        IAuctionListing(_listing).cancelAuction();

        emit LogCanceled(_listing);
    }

    /**
    * @dev Gets the token distribution status at a specific address
    * @param _listing The address of the listing
    */
    function getTokenDistributionStatus (address _listing) external view returns(bool){
        return tokensDistributed[_listing];
    }

    /**
    * @dev Transfer an amount of money in escrow in this contract to a target address
    * @param _destination The address to deposit the funds to
    * @param _amount The amount to be transfered
    */
    function transferTo (address payable _destination, uint256 _amount) external onlyWhitelistAdmin{
        require(_amount <= address(this).balance, "Amount is larger than the contract balance");
        _destination.transfer(_amount);
    }
} 