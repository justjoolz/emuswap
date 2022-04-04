
import StakingRewards from "../../contracts/StakingRewards.cdc"

pub fun main(id: UInt64): {Address: StakingRewards.StakeInfo} {
    return StakingRewards.borrowFarm(id: id)?.readStakes()!
}

