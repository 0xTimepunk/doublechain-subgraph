import {
  BuyOfferMade,
  SellOfferMade,
  BuyOfferCancelled,
  SellOfferCancelled,
  TransactionMade,
  UserAdded,
  UserRemoved,
  ProducerAdded,
  ProducerRemoved,
} from '../generated/EnergyMarket/EnergyMarket'
import { User, Producer, BuyOffer, SellOffer, Transaction } from '../generated/schema'

export function handleBuyOfferMade(event: BuyOfferMade): void {
  let buyOffer = new BuyOffer(event.params.index.toHex())

  buyOffer.buyer = event.params.buyer
  buyOffer.energy = event.params.energy
  buyOffer.maxPricePerUnit = event.params.maxPricePerUnit
  buyOffer.mustBeWhole = event.params.mustBeWhole
  buyOffer.completed = false

  buyOffer.save()
}

export function handleSellOfferMade(event: SellOfferMade): void {
  let sellOffer = new SellOffer(event.params.index.toHex())

  sellOffer.seller = event.params.seller
  sellOffer.energy = event.params.energy
  sellOffer.minPricePerUnit = event.params.minPricePerUnit
  sellOffer.mustBeWhole = event.params.mustBeWhole
  sellOffer.completed = false

  sellOffer.save()
}

export function handleBuyOfferCancelled(event: BuyOfferCancelled): void {
  let id = event.params.index.toHex()
  let buyOffer = BuyOffer.load(id)

  buyOffer.completed = true

  buyOffer.save()
}

export function handleSellOfferCancelled(event: SellOfferCancelled): void {
  let id = event.params.index.toHex()
  let sellOffer = SellOffer.load(id)

  sellOffer.completed = true

  sellOffer.save()
}

export function handleTransactionMade(event: TransactionMade): void {
  let transaction = new Transaction(
    event.transaction.hash.toHex() + '-' + event.logIndex.toString(),
  )

  transaction.buyOfferId = event.params.buyIndex
  transaction.sellOferId = event.params.sellIndex
  transaction.energy = event.params.energy
  transaction.pricePerUnit = event.params.pricePerUnit

  transaction.save()
}

export function handleUserAdded(event: UserAdded): void {
  let user = new User(event.params._user.toHex())

  user.address = event.params._user
  user.active = true

  user.save()
}

export function handleUserRemoved(event: UserRemoved): void {
  let address = event.params._user.toHex()
  let user = User.load(address)

  user.active = false

  user.save()
}

export function handleProducerAdded(event: ProducerAdded): void {
  let producer = new Producer(event.params._producer.toHex())

  producer.address = event.params._producer
  producer.active = true

  producer.save()
}

export function handleProducerRemoved(event: ProducerRemoved): void {
  let address = event.params._producer.toHex()
  let producer = Producer.load(address)

  producer.active = false
  producer.save()
}
