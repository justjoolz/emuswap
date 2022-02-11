import EmuSwap from "../../contracts/exchange/EmuSwap.cdc"

pub fun main(poolID: UInt64, amount: UFix64): {String:UFix64} {
    let poolRef = EmuSwap.borrowPool(id: poolID)
    return {    "exact A for B": poolRef!.quoteSwapExactToken1ForToken2(amount: amount),
                "exact B for A": poolRef!.quoteSwapExactToken2ForToken1(amount: amount),
                "A for exact B": poolRef!.quoteSwapToken1ForExactToken2(amount: amount),
                "B for exact A": poolRef!.quoteSwapToken2ForExactToken1(amount: amount)
        }
}