const ListingFactory = artifacts.require("ListingFactory");
const ListingInteraction = artifacts.require("ListingInteraction");
const AuctionListing = artifacts.require("AuctionListing");

module.exports = async function(done){

    let accounts =  await web3.eth.getAccounts();
    let factory = await ListingFactory.deployed();
    let interaction = await ListingInteraction.deployed();
    let listings = await factory.getListingAddresses();
    let listing1 = await AuctionListing.at(listings[0]);
    let listing2 = await AuctionListing.at(listings[1]);

    let listingData1 = await listing1.getListingData();
    let listingData2 = await listing2.getListingData();

    let maxPrice1 = listingData1[9]
    let maxPrice2 = listingData2[9]

    const usersToJoin = [accounts[1], accounts[2]];
    
    const qtys = [1,2];

    const values1 =  qtys.map(x => x*maxPrice1);
    const values2 =  qtys.map(x => x*maxPrice2);

    console.log(values1)
    console.log(values2)

    let promises = usersToJoin.map((user,idx) => interaction.joinListingAsBuyer(
        listings[0], 
        qtys[idx],
        {from: user,value: values1[idx]}));
    try {
        await Promise.all(promises);
        console.log('Account 1 and 2 joined listing: ' && listings[0]);
    } catch (error) {
        console.log(error.message);
    }
    let promises2 = usersToJoin.map((user,idx) => interaction.joinListingAsBuyer(
        listings[1], 
        qtys[idx],
        {from: user,value: values2[idx]}));
    try {
        await Promise.all(promises2);
        console.log('Account 1 and 2 joined listing: ' && listings[1]);
    } catch (error) {
        console.log(error.message);
    }
    done();

};