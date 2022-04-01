
import StakingRewards from "../../contracts/StakingRewards.cdc"

pub fun main(id: UInt64): StakingRewards.FarmInfo? {
    return StakingRewards.getFarmInfo(id: id)
}

