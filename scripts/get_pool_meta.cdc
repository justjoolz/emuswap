import EmuSwap from "../contracts/EmuSwap.cdc"

pub fun main(poolID: UInt64): EmuSwap.PoolMeta {
    let poolRef = EmuSwap.borrowPool(id: poolID)
    return poolRef!.getPoolMeta()
}