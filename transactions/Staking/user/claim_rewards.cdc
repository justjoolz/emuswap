// create_new_pool.cd 
//
// This transaction withdraws lp tokens from users account and stakes them

import FungibleToken from "../../../contracts/dependencies/FungibleToken.cdc"
import FungibleTokens from "../../../contracts/dependencies/FungibleTokens.cdc"
import EmuSwap from "../../../contracts/exchange/EmuSwap.cdc"
import EmuToken from "../../../contracts/EmuToken.cdc"
import StakingRewards from "../../../contracts/StakingRewards.cdc"

// hardcoded to create Flow/FUSD pool
import FlowToken from "../../../contracts/dependencies/FlowToken.cdc"
import FUSD from "../../../contracts/dependencies/FUSD.cdc"

transaction(farmID: UInt64) {
 
  let stakeControllerCollectionRef: &StakingRewards.StakeControllerCollection

  prepare(signer: AuthAccount) {
    // get stake controller collection ref 
    self.stakeControllerCollectionRef = signer.borrow<&StakingRewards.StakeControllerCollection>(from: StakingRewards.CollectionStoragePath)!
  }

  execute {
    // get reference to farm
    let farmRef = StakingRewards.borrowFarm(id: farmID)!
  
    // stake the tokens and optionally receive a controller if first time staking
    let stakingController = self.stakeControllerCollectionRef.borrow(id: farmID)! as &StakingRewards.StakeController

    // sends them to the receiver cap provided when staking.... j00lz maybe only store caps in the stake not in the controller too?
    farmRef.claimRewards(stakeControllerRef: stakingController)
  }
}


