import EmuSwap from "../../contracts/exchange/EmuSwap.cdc"

pub fun main(poolID: UInt64, amount: UFix64): UFix64 {
    let poolRef = EmuSwap.borrowPool(id: poolID)
    return poolRef!.quoteSwapExactToken1ForToken2(amount: amount)
}