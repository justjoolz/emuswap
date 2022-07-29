
import StakingRewards from "../../contracts/StakingRewards.cdc"

pub fun main(id: UInt64, address: Address):  StakingRewards.StakeInfo {
    let stakeCollection = getAccount(address).getCapability(StakingRewards.CollectionPublicPath)
    let collection = stakeCollection.borrow<&StakingRewards.StakeControllerCollection>()
    return collection!.getStakeMeta(id: id)
}

