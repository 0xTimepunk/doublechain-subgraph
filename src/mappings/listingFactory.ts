import { ListingProduced } from '../../generated/ListingFactory/ListingFactory'
import { Listing } from '../../generated/schema'
import { AuctionListing } from '../../generated/templates'

export function handleListingProduced(event: ListingProduced): void {
  let listing = new Listing(event.params.listingAddress.toHexString())

  listing.creator = event.params.creator

  listing.save()

  AuctionListing.create(event.params.listingAddress)
}
