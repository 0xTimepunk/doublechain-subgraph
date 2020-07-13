const TrackingToken = artifacts.require("TrackingToken");
const ListingInteraction = artifacts.require("ListingInteraction");
const ListingFactory = artifacts.require("ListingFactory");

contract("TrackingToken", async () => {
  it("Should deploy smart contract properly", async () => {
    const trackingToken = await TrackingToken.deployed();
    assert(trackingToken.address !== "");
  });
});

contract("ListingInteraction", async () => {
  it("Should deploy smart contract properly", async () => {
    const listingInteraction = await ListingInteraction.deployed();
    assert(listingInteraction.address !== "");
  });
});

contract("ListingFactory", async () => {
  it("Should deploy smart contract properly", async () => {
    const listingFactory = await ListingFactory.deployed();
    assert(listingFactory.address !== "");
  });
});
