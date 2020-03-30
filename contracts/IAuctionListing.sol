pragma solidity ^0.5.0;

interface IAuctionListing {
    
    /***********************************|
    |             Functions             |
    |__________________________________*/
    
    function pushBuyer (address _participant, uint256 _quantity) external payable;
    function cancelBuyer (address payable _buyer) external returns (uint256);
    function pushSupplier (address _participant, bytes32 _encryptedBid, uint64 _merit) external payable;
    function revealBid (address payable _participant, uint256 _unencryptedBid, uint256 _nonce) external;
    function initiateDelivery (address _winner, address _buyer, address _transporter, bytes32 _publicSKey) external;
    function keyVerification (address _buyer, bytes32 _privateSKey) external returns (bool, uint256, address);
    function withdraw(address payable _beneficiary) external returns (uint256);
    function cancelAuction() external;
    function getQuantities () external view returns (uint256, uint256);
    function getMaxPrice () external view returns (uint256);
    function getWinner () external view returns (address );
    function isRevealPeriodOver () external view returns (bool);
    function getBuyers () external view returns (address[] memory);
    function getListingURI() external view returns (string memory);
}
