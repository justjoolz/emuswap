// get_dao_fee_percentage.cdc

import EmuSwap from "../contracts/exchange/EmuSwap.cdc"

pub fun main(): UFix64 {
    return EmuSwap.getDAOFeePercentage()
}