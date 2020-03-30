pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/access/roles/WhitelistAdminRole.sol";
import "./Tokens/Reputation/DBLReputation.sol";

//General Considerations:
//addUser function requires inputting an user type -> create instead three separable addUser functions for each role type?
contract ListingRoles is WhitelistAdminRole, DBLReputation {
    using Roles for Roles.Role;

    /***********************************|
    |             Events                |
    |__________________________________*/

    event UserAdded(address indexed account, string role);
    event UserRemoved(address indexed account);

    /***********************************|
    |             Storage               |
    |__________________________________*/

    Roles.Role private clients;
    Roles.Role private suppliers;
    Roles.Role private transporters;
    
    /***********************************|
    |             Modifiers             |
    |__________________________________*/

    modifier onlyFirstTime () {
        require(!isClient(msg.sender) && !isSupplier(msg.sender) && !isTransporter(msg.sender),"The user is already registered");
        _;
    }

    modifier onlyClient () {
        require(isClient(msg.sender),"The user is not a client");
        _;
    }
    modifier onlySupplier () {
        require(isSupplier(msg.sender),"The user is not a supplier");
        _;
    }

    modifier onlyTransporter () {
        require(isTransporter(msg.sender),"The user is not a transporter");
        _;
    }

    modifier onlyAuthWithdrawees () {
        require(isClient(msg.sender)||isSupplier(msg.sender),"The user is not authorized to withdraw");
        _;
    }

    modifier onlyWhitelistAdmin () {
        require(isWhitelistAdmin(msg.sender),"The user is not an admin on the factory");
        _;
    }

    /***********************************|
    |             Functions             |
    |__________________________________*/

    /**
    * @dev Checks if an account is a registered client
    * @param _account The address to check
    */
    function isClient(address _account) public view returns (bool) {
        return clients.has(_account);
    }

    /**
    * @dev Checks if an account is a registered supplier
    * @param _account The address to check
    */
    function isSupplier(address _account) public view returns (bool) {
        return suppliers.has(_account);
    }

    /**
    * @dev Checks if an account is a registered transporter
    * @param _account The address to check
    */
    function isTransporter(address _account) public view returns (bool) {
        return transporters.has(_account);
    }

    /**
    * @dev Registers a new user into the platform. Users register themselves and can only register
    * @dev to a single role.
    * @param _userType The role type, 1=client, 2= supplier, 3=transporter
    */
    function addUser(uint256 _userType) public onlyFirstTime {
        // retirar caso em que _userType == 0
        require(_userType < 4, "Invalid user type");
        if (_userType == 1){
            clients.add(msg.sender);
            emit UserAdded(msg.sender, "buyer");
            
        } else if(_userType == 2){
            suppliers.add(msg.sender);

            _createReputation(msg.sender, 5);

            emit UserAdded(msg.sender, "supplier");
        } else if(_userType == 3) {
            transporters.add(msg.sender);
            emit UserAdded(msg.sender, "transporter");
        }
    }

    /**
    * @dev Removes a user from the platform. Only admins can currently remove accounts
    * @param _account The account to remove
    * @param _userType The role type, 1=client, 2=supplier, 3=transporter
    */
    function removeUser(address _account, uint256 _userType) public onlyWhitelistAdmin{
        require(_userType < 4, "Invalid user type");
        if (_userType == 1){
            clients.remove(_account);
            emit UserRemoved(_account);
        } else if(_userType == 2){
            suppliers.remove(_account);
            emit UserRemoved(_account);
        } else if(_userType == 3) {
            transporters.remove(_account);
            emit UserRemoved(_account);
        }
    }

    /**
    * @dev Gets the reputation score for a given repid
    * @param _RepId The id of the reputation to get
    */
    function getReputationAtId (uint256 _RepId) view external 
    returns 
    (uint64 _creationTime, uint64 _score, bool _active)
    {
        // Check that the address is owner of reputation.
        require(_owns(msg.sender,_RepId), "The sender is not the owner of the given RepId");

        Reputation storage _reputation = reputations[_RepId];

        _creationTime = _reputation.creationTime;
        _score = _reputation.score;
        _active = _reputation.active;   
    }

    /**
    * @dev Gets the total reputation score for a given address
    */
    function _getTotalReputationScore () public view returns (uint64)
    {
        uint256 len = ownerToReputations[msg.sender].length;
        uint64 totalScore = 0;

        for (uint256 i=0; i < len; i++) {
            Reputation memory _reputation = reputations[ownerToReputations[msg.sender][i]];
            if(_reputation.active){
                totalScore+=_reputation.score;
            }
        }

        return totalScore;
    }

    /**
    * @dev Getter for returning list of reputations for owner.
    */
    function getReputionIdWithAddress(address _owner) view external returns (uint256[] memory)
    {
        return ownerToReputations[_owner];
    }

    /**
    * @dev Expires a given _RepId. Can only be called by the _RepId owner-
    * @param _RepId The id of the reputation to get
    */
    function expireReputation(uint256 _RepId) external
    {
        // Only owner of reputation can expire the reputation.
        require(_owns(msg.sender,_RepId));
        require(reputations[ownerToReputations[msg.sender][_RepId]].creationTime + expirationTime >= block.timestamp, "The expiry time hasn't passed yet");
        
        reputations[ownerToReputations[msg.sender][_RepId]].active = false;
    }


    /**
    * @dev Sets Reputation expiration time
    * @param _expirationTime The expiration time
    */
    function setExpirationTime (uint256 _expirationTime) external onlyWhitelistAdmin {
        expirationTime = uint64(_expirationTime);
    }
}