import EmuSwap from "../contracts/exchange/EmuSwap.cdc"

pub fun main(): {String: UFix64} {
    log(EmuSwap.readFeesCollected())
    return EmuSwap.readFeesCollected()
}