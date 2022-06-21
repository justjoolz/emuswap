// get_lp_fee_percentage.cdc

import EmuSwap from "../contracts/EmuSwap.cdc"

pub fun main(): UFix64 {
    return EmuSwap.getLPFeePercentage()
}