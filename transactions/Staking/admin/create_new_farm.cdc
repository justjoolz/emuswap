// create_new_pool.cd 
//
// This transaction creates a new incentive farm for an existing EmuSwap pool
// Holder of the corresponding LP tokens can stake them in this Farm to receive all staking rewards from all RewardsPools that have weight assigned to this farm.

import StakingRewards from "../../../contracts/StakingRewards.cdc"

transaction(poolID: UInt64) {

  let adminRef: &StakingRewards.Admin

  prepare(signer: AuthAccount) {
    self.adminRef = signer.borrow<&StakingRewards.Admin>(from: StakingRewards.AdminStoragePath) ?? panic("Cannot borrow Staking rewards admin")
  }

  execute {
    self.adminRef.createFarm(poolID: poolID)
  }
}
