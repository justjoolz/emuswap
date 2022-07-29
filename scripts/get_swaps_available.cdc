// get_swaps_available.cdc

import EmuSwap from "../contracts/EmuSwap.cdc"

pub fun main(tokenIdentifier: String): {String: UInt64}? {
    return EmuSwap.getSwapsAvailableForToken(identifier: tokenIdentifier)
}