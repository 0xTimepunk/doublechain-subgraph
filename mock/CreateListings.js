const ListingFactory = artifacts.require("ListingFactory");
const ListingInteraction = artifacts.require("ListingInteraction");

module.exports = async function(done){
    let accounts =  await web3.eth.getAccounts();

    const uris = ["Laptop","Smartphone","Smart TV","Headphones","Keyboard","Mouse"];
    const groupable = [true, true, true, true, false, false];
    const ltMax = [
        510061, 
        412412, 
        312321, 
        766575, 
        1400000, 
        967877];
    const maxPrice = [1000, 800, 500, 100, 50, 40];
    const minMerit = [3, 4, 5, 1, 2, 5];

    const creators = [accounts[1],accounts[1],accounts[2],accounts[2], accounts[3], accounts[3]];
    const creationFee = web3.utils.toWei("1", "finney");

    let factory = await ListingFactory.deployed();
    let interaction = await ListingInteraction.deployed();

    await interaction.addUser (1,{from: accounts[1]});
    await interaction.addUser (1,{from: accounts[2]});
    await interaction.addUser (1,{from: accounts[3]});
    await interaction.addUser (2,{from: accounts[4]});
    await interaction.addUser (2,{from: accounts[5]});
    await interaction.addUser (2,{from: accounts[6]});
    await interaction.addUser (3,{from: accounts[7]});

    //dates are in unix seconds (60 second differece between phases to test)
    const creationTime = Math.floor(Date.now() / 1000) + 20;
    const auctionTime = Math.floor(Date.now() / 1000) + 40;
    const endTime = Math.floor(Date.now() / 1000) + 55;

    let promises = uris.map( (uri,idx) => factory.newListing(
        uri, 
        groupable[idx],
        ltMax[idx],
        creationTime,
        auctionTime,
        endTime,
        minMerit[idx],
        maxPrice[idx],
        {from: creators[idx],value: creationFee}));
    try {
        await Promise.all(promises);
        console.log('Listings created.');
    } catch (error) {
        console.log(error.message);
    }
    done();

};