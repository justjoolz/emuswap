
import StakingRewards from "../../contracts/StakingRewards.cdc"

pub fun main(id: UInt64, address: Address): Fix64 {
    return StakingRewards.borrowFarm(id: id)?.getPendingRewards(address: address)!
}

