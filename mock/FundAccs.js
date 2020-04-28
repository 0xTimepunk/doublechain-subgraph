
module.exports = async function(done){
    let accounts =  await web3.eth.getAccounts();
    try {
        // portis
        await web3.eth.sendTransaction({from: accounts[0], to: "0xff23bc46ad602101b02d857c867b7c7069dc908a", value: web3.utils.toWei("1","ether")})
        // fortmatic
        await web3.eth.sendTransaction({from: accounts[0], to: "0xBfAD455bDF38F154c0283bD6F9e5C9584dfe48d4", value: web3.utils.toWei("1","ether")})
        // torus
        await web3.eth.sendTransaction({from: accounts[0], to: "0xc6444E7c335d06c9570b243e457032530A1685A0", value: web3.utils.toWei("1","ether")})
        // squarelink
        await web3.eth.sendTransaction({from: accounts[0], to: "0x6d58b1d6e5a8b7a30944747d7495511cfe467c29", value: web3.utils.toWei("1","ether")})
        // walletConnect
        await web3.eth.sendTransaction({from: accounts[0], to: "0x0818410b47472be07D8287fF0622a015Cc638442", value: web3.utils.toWei("1","ether")})

    } catch (error) {
        console.log(error.message);
    }
    done();

};