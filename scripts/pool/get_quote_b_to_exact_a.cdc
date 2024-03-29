import EmuSwap from "../../contracts/EmuSwap.cdc"

pub fun main(poolID: UInt64, amount: UFix64): UFix64 {
    let poolRef = EmuSwap.borrowPool(id: poolID)
    return poolRef!.quoteSwapToken2ForExactToken1(amount: amount)
}