pragma solidity ^0.5.0;

/**
* Contains all constants, data types, and basic functionality.
* @notice Inspired by https://github.com/philipglazman/Source
*/
contract DBLReputation {

    /**
    * RepId - Reputation identifier. It is the relationship between party A and party B. 
    */

    /***
    Events 
    ***/
    event Transfer(address _to, uint256 _RepId);

    /***
    Data Types 
    ***/

    struct Reputation 
    {         
        // Time the reputation was created.
        uint64 creationTime;
        
        // Score judging the choices of the recipient. 
        uint64 score;

        // Flag to set the reputation as active or not
        bool active;
    }

    Reputation[] reputations;


    // Mapping that counts the number of reputations a person has. 2^32 are the maximum reputations.
    mapping (address => uint256) internal ownershipReputationsCount;

    // Mapping each user to the list of reputations.
    mapping (address => uint256[]) internal ownerToReputations;

    // Maps the reputation id to the owner.
    mapping (uint256 => address) internal reputationToOwner;

    uint64 expirationTime;

    constructor () public {
        expirationTime = 160000000;
    }

    /*** 
    Utility Functions
    ***/

    // Returns the owner of a reputation.
    function _owns(address _owner, uint256 _RepId) view internal returns (bool) 
    {
        return reputationToOwner[_RepId] == _owner;
    }

    // Creates reputation.
    function _createReputation(address _owner, uint64 _score) internal
    {
        require(_score > 0, "Reputation to be added should be higher than 0");
        Reputation memory _reputation;

        _reputation.creationTime = uint64(block.timestamp);
        _reputation.score = uint64(_score);
        _reputation.active = true;
        
        uint256 RepId = reputations.push(_reputation)-1;

        ownershipReputationsCount[_owner]++;
        ownerToReputations[_owner].push(RepId);
        reputationToOwner[RepId] = _owner;

        emit Transfer(_owner,RepId);

    }

}
