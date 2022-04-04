import EmuSwap from "../contracts/exchange/EmuSwap.cdc"

pub fun main(): {String: UFix64} {
    return EmuSwap.readFeesCollected()
}