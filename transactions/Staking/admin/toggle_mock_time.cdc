// create_new_pool.cd 
//
// This transaction creates a new incentive farm for an existing EmuSwap pool  

import StakingRewards from "../../../contracts/StakingRewards.cdc"

transaction() {

  let adminRef: &StakingRewards.Admin

  prepare(signer: AuthAccount) {
    self.adminRef = signer.borrow<&StakingRewards.Admin>(from: StakingRewards.AdminStoragePath) ?? panic("Cannot borrow Staking rewards admin")
  }

  execute {
    self.adminRef.toggleMockTime()
    log("toggled and transaction calls StakingRewards.now()")
    log(StakingRewards.now())
  }
}
