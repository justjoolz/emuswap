
import StakingRewards from "../../contracts/StakingRewards.cdc"

pub fun main(id: UInt64): StakingRewards.FarmMeta? {
    return StakingRewards.getFarmMeta(id: id)
}

