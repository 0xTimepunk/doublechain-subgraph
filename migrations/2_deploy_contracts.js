var TrackingToken = artifacts.require("./Tokens/Tracking/ERC1155/TrackingToken.sol");
var ListingInteraction = artifacts.require("./ListingInteraction.sol");
var ListingFactory = artifacts.require("./ListingFactory.sol");

module.exports = async function(deployer, network, accounts) {
  deployer.then(async() => {
    await deployer.deploy(TrackingToken,{from: accounts[0]});
    await deployer.deploy(ListingInteraction, accounts[0], TrackingToken.address,{from: accounts[0]});
    await deployer.deploy(ListingFactory, ListingInteraction.address, accounts[0],{from: accounts[0]});
  }).then( async () => {

    const trackingTokenContract = await TrackingToken.deployed();
    const listingInteractionContract = await ListingInteraction.deployed();
    const listingFactoryContract = await ListingFactory.deployed();

    console.log('Tracking token contract created at:', trackingTokenContract.address)
    console.log('Listings interface created at:', listingInteractionContract.address)
    console.log('Listing factory created at:', listingFactoryContract.address)

    await trackingTokenContract.transferPrimary(listingInteractionContract.address, {from: accounts[0]});

    console.log("Tracking token primary transfered to: ", listingInteractionContract.address);
    }
  )
};