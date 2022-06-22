// get_pool_id_from_token_ids.cdc

import EmuSwap from "../contracts/EmuSwap.cdc"

pub fun main(token1: String, token2: String): UInt64? {
    return EmuSwap.getPoolIDFromIdentifiers(token1: token1, token2: token2)
}