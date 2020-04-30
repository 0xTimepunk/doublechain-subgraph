import {
  UserAdded,
  UserRemoved,
  NewBuyer,
  LeftListing,
  SupplierJoined,
  DistributionComplete
} from '../../generated/ListingInteraction/ListingInteraction'
import { Listing, Buyer, User, Supplier, Bid } from '../../generated/schema'
import { zeroBigInt, convertWeiToEth, zeroBD } from './helpers'

export function handleUserAdded(event: UserAdded): void {
  let user = new User(event.params.account.toHexString())

  user.role = event.params.role
  user.active = true

  user.save()
}

export function handleUserRemoved(event: UserRemoved): void {
  let user = User.load(event.params.account.toHexString())

  user.active = false
  user.save()
}

export function handleNewBuyer(event: NewBuyer): void {
  let buyer = new Buyer(
    event.params.buyer.toHexString() + '-' + event.params.listingAddress.toHexString(),
  )

  buyer.weiAmount = event.params.depositedWei
  buyer.weiAmountEth = convertWeiToEth(event.params.depositedWei)
  buyer.quantity = event.params.quantity
  buyer.canWithdraw = false
  buyer.isParticipating = true
  buyer.listing = event.params.listingAddress.toHexString()
  buyer.user = event.params.buyer.toHexString()
  buyer.blockNumber = event.block.number
  buyer.transactionHash = event.transaction.hash
  buyer.save()

  let listing = Listing.load(event.params.listingAddress.toHexString())

  listing.quantityToFulfil =  listing.quantityToFulfil.plus(event.params.quantity)
  listing.totalQuantity = listing.totalQuantity.plus(event.params.quantity)

  listing.save()
}

export function handleLeftListing(event: LeftListing): void {
  let buyer = Buyer.load(
    event.params.buyer.toHexString() + '-' + event.params.listingAddress.toHexString(),
  )
  let listing = Listing.load(event.params.listingAddress.toHexString())


  listing.quantityToFulfil =  listing.quantityToFulfil.minus(buyer.quantity)
  listing.totalQuantity = listing.totalQuantity.minus(buyer.quantity)

  buyer.weiAmount = zeroBigInt()
  buyer.weiAmountEth = zeroBD()
  buyer.quantity = zeroBigInt()
  buyer.isParticipating = false

  buyer.save()

  let buyers = listing.buyers

  let index = buyers.indexOf(buyer.id)

  if (index > -1) {
    buyers.splice(index, 1)
  }

  listing.buyers = buyers

  listing.save()
}

export function handleSupplierJoined(event: SupplierJoined): void {
  let supplier = new Supplier(
    event.params.supplier.toHexString() + '-' + event.params.listingAddress.toHexString()
  )

  supplier.weiAmount = event.params.depositedWei
  supplier.weiAmountEth = convertWeiToEth(event.params.depositedWei)
  supplier.isParticipating = true
  supplier.revealed = false
  supplier.refunded = false
  supplier.invalidBid = false
  supplier.canWithdraw = false
  supplier.listing = event.params.listingAddress.toHexString()
  supplier.user = event.params.supplier.toHexString()
  supplier.bid = event.params.supplier.toHexString() + '-' + event.params.listingAddress.toHexString()
  supplier.joinedBlock = event.block.number 
  
  supplier.save()

  let bid = new Bid(
    event.params.supplier.toHexString() + '-' + event.params.listingAddress.toHexString()
  )

  bid.encryptedBid = event.params.encryptedBid
  bid.blockNumber = event.block.number
  bid.transactionHash = event.transaction.hash
  bid.transactionLogIndex = event.transactionLogIndex

  bid.save()
}

export function handleDistributionComplete(event: DistributionComplete): void {
  let listing = Listing.load(event.params.listingAddress.toHexString())

  listing.tokenID = event.params.typeID

  listing.save()
}