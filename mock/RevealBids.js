const ListingFactory = artifacts.require("ListingFactory");
const ListingInteraction = artifacts.require("ListingInteraction");

module.exports = async function(done){
    let accounts =  await web3.eth.getAccounts();
    let factory = await ListingFactory.deployed();
    let interaction = await ListingInteraction.deployed();
    
    let listings = await factory.getListingAddresses();  
   
    const usersToReveal = [accounts[4], accounts[5]];
    const unencryptedBids = [900,
    800];

    let promises = usersToReveal.map((user,idx) => interaction.revealBid(
        listings[0], 
        unencryptedBids[idx],
        1,
        {from: user}));
    try {
        await Promise.all(promises);
    } catch (error) {
        console.log(error.message);
    }
    done();

};