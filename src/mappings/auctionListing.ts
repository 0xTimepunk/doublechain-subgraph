import { zeroBigInt, convertWeiToEth, zeroBD, equalToZeroBI, equalToOneBI } from './helpers'
import { 
  ListingBuilt,
  RevealMade,
  WinnerUpdated,
  RefundMade,
  InvalidBid,
  FullWithdrawal
} from '../../generated/templates/AuctionListing/AuctionListing'
import { Listing, Supplier, Bid, Buyer} from '../../generated/schema'

export function handleListingBuilt(event: ListingBuilt): void {
  let listing = Listing.load(event.params.listingAddress.toHexString())

  listing.canceled = false
  listing.groupable = event.params.groupable
  listing.hasSuppliers = false
  listing.winner = event.params.winner
  listing.ltMax = event.params.ltMax
  listing.creationTime = event.params.creationTime
  listing.auctionTime = event.params.auctionTime
  listing.endTime = event.params.endTime
  listing.revealTime = event.params.revealTime
  listing.minMerit = event.params.minMerit
  listing.maxPrice = event.params.maxPrice
  listing.maxPriceEth = convertWeiToEth(event.params.maxPrice)
  listing.highestBid = event.params.maxPrice
  listing.highestBidEth = convertWeiToEth(event.params.maxPrice)
  listing.address = event.params.listingAddress
  listing.uri = event.params.productURI
  listing.quantityToFulfil = zeroBigInt()
  listing.totalQuantity = zeroBigInt()
  listing.fPBid = event.params.fPBid.toI32()

  listing.save()
}

export function handleRevealMade(event: RevealMade): void {
  let supplier = Supplier.load(event.params.revealee.toHexString()+ '-' + event.params.listing.toHexString())
  let bid = Bid.load(event.params.revealee.toHexString()+ '-' + event.params.listing.toHexString())

  supplier.weiAmount = zeroBigInt()
  supplier.weiAmountEth = zeroBD()
  supplier.revealed = true
  supplier.refunded = true

  supplier.save()

  bid.unencryptedBid = event.params.unencryptedBid
  bid.unencryptedBidEth = convertWeiToEth(event.params.unencryptedBid)

  bid.save()
}

export function handleWinnerUpdated(event: WinnerUpdated): void {
  let listing = Listing.load(event.params.listing.toHexString())

  listing.winner = event.params.winner
  listing.highestBid = event.params.highestBid
  listing.highestBidEth = convertWeiToEth(event.params.highestBid)

  listing.save()

}

export function handleRefundMade(event: RefundMade): void {
  let refundee = Supplier.load(event.params.refundee.toHexString()+ '-' + event.params.listing.toHexString())

  refundee.refunded = true

  refundee.save()
}

export function handleInvalidBid(event: InvalidBid): void {
  let supplier = Supplier.load(event.params.bidder.toHexString()+ '-' + event.params.listing.toHexString())
  let bid = Bid.load(event.params.bidder.toHexString()+ '-' + event.params.listing.toHexString())

  supplier.weiAmount = zeroBigInt()
  supplier.weiAmountEth = zeroBD()
  supplier.revealed = true
  supplier.refunded = true
  supplier.invalidBid = true

  supplier.save()
  
  bid.unencryptedBid = event.params.unencryptedBid
  bid.unencryptedBidEth = convertWeiToEth(event.params.unencryptedBid)

  bid.save()
}

export function handleFullWithdrawal(event: FullWithdrawal): void {
  let userType = event.params.userType

  if(equalToOneBI(userType)){
    let supplier = Supplier.load(event.params.withdrawee.toHexString()+ '-' + event.params.listing.toHexString())
    supplier.weiAmount = zeroBigInt()
    supplier.weiAmountEth = zeroBD()
    supplier.withdrawn = true
    supplier.isParticipating = false

    supplier.save()
  } else if (equalToZeroBI(userType)){
    let buyer = Buyer.load(event.params.withdrawee.toHexString()+ '-' + event.params.listing.toHexString())
    buyer.weiAmount = zeroBigInt()
    buyer.weiAmountEth = zeroBD()
    buyer.withdrawn = true
    buyer.isParticipating = false

    buyer.save()

  }

}

