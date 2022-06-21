import EmuSwap from "../contracts/EmuSwap.cdc"

pub fun main(): {String: UFix64} {
    return EmuSwap.readFeesCollected()
}