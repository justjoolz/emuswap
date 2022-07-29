// unstake.cdc 
//
// This transaction unstake an amount of LP tokens from any farm 

import StakingRewards from "../../../contracts/StakingRewards.cdc"

transaction(farmID: UInt64, amount: UFix64) {

  // the signers auth account to pass to execute block
  let signer: AuthAccount

  prepare(signer: AuthAccount) {
    self.signer = signer
  }

  execute {

    let collectionRef = self.signer.borrow<&StakingRewards.StakeControllerCollection>(from: StakingRewards.CollectionStoragePath) ?? panic("could not borrow staking collection")
    let stakeControllerRef = collectionRef.borrow(id: farmID)!
    let farmRef = StakingRewards.borrowFarm(id: farmID)!

    farmRef.unstake(amount: amount, stakeControllerRef: stakeControllerRef) 
  }
}


