import EmuSwap from "../contracts/exchange/EmuSwap.cdc"

pub fun main():[EmuSwap.PoolMeta] {
    let meta: [EmuSwap.PoolMeta] = []
    for ID in EmuSwap.getPoolIDs() {
        let poolRef = EmuSwap.borrowPool(id: ID)
        meta.append(
            poolRef!.getPoolMeta()
        )
    }
    return meta
}