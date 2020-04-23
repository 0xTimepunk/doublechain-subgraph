
module.exports = async function(done){
    let accounts =  await web3.eth.getAccounts();
    try {
        await web3.eth.sendTransaction({from: accounts[0], to: "0xa9A2F37290dAE9152552FF4906af53Dc4E580fE0", value: web3.utils.toWei("1","ether")})
    } catch (error) {
        console.log(error.message);
    }
    done();

};