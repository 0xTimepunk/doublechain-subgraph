import {
  TransferSingle
} from '../../generated/TrackingToken/TrackingToken'
import { Token } from '../../generated/schema'

export function handleTransferSingle(event: TransferSingle): void {
  if (event.params._from.toHexString() === '0x0' && event.params._to.toHexString() === '0x0'){
    let initialToken = new Token(event.params._id.toString())

    initialToken.owner = event.params._to
    initialToken.value = event.params._value

    initialToken.save()
  } else if (event.params._from.toHexString() === '0x0' && event.params._to.toHexString() !== '0x0'){
    let transferToken = Token.load(event.params._id.toString())

    transferToken.owner = event.params._to
    transferToken.buyer = event.params._to.toHexString()
    transferToken.value = event.params._value

    transferToken.save()
  }
}