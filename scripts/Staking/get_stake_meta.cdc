
import StakingRewards from "../../contracts/StakingRewards.cdc"

pub fun main(id: UInt64, address: Address): UFix64 {
    return StakingRewards.borrowFarm(id: id)?.getPendingRewards(address: address)!
}

