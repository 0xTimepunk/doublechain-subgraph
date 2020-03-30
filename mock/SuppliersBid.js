const ListingFactory = artifacts.require("ListingFactory");
const ListingInteraction = artifacts.require("ListingInteraction");
const AuctionListing = artifacts.require("AuctionListing");

module.exports = async function(done){
    let accounts =  await web3.eth.getAccounts();
    let factory = await ListingFactory.deployed();
    let interaction = await ListingInteraction.deployed();
    
    let listings = await factory.getListingAddresses();  
   
    const usersToBid = [accounts[4], accounts[5]];
    const encryptedBids = ['0x31e396976d1d09fba39348dc2bacc5eeba6be66a8c29121638d83d4727d6b51b',
    '0xf0f85d6caef7223e780326f99da3372056c66975e92ad1622153b0d5e2af710a'];

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