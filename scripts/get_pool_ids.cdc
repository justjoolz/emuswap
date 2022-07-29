import EmuSwap from "../contracts/EmuSwap.cdc"

pub fun main(): [UInt64] {
    return EmuSwap.getPoolIDs()
}