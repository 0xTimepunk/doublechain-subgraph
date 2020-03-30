const ListingFactory = artifacts.require("ListingFactory");
const ListingInteraction = artifacts.require("ListingInteraction");
const AuctionListing = artifacts.require("AuctionListing");

module.exports = async function(done){
    let accounts =  await web3.eth.getAccounts();
    let factory = await ListingFactory.deployed();
    let interaction = await ListingInteraction.deployed();
    
    let listings = await factory.getListingAddresses();  
   
    const usersToBid = [accounts[4], accounts[5]];
    const encryptedBids = ['0x27a80c2b1a714a739d6b916aee9e407181b310303f5c43ba2ada127a885ce3c9',
    '0x30697f2226c1858f572d7ff05c573eee84c816c57b506a1a84973ab8a53fad43'];

    let promises = usersToBid.map((user,idx) => interaction.joinListingAsSupplier(
        listings[0], 
        encryptedBids[idx],
        {from: user,value: 300}));
    try {
        await Promise.all(promises);
        console.log('Account 4 and 5 joined listing: ' && listings[0]);
    } catch (error) {
        console.log(error.message);
    }
    done();

};