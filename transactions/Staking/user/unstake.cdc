// create_new_pool.cd 
//
// This transaction creates a new Flow/FUSD pool..... 

import FungibleToken from "../../../contracts/dependencies/FungibleToken.cdc"
import FungibleTokens from "../../../contracts/dependencies/FungibleTokens.cdc"
import EmuSwap from "../../../contracts/exchange/EmuSwap.cdc"
import EmuToken from "../../../contracts/EmuToken.cdc"
import StakingRewards from "../../../contracts/StakingRewards.cdc"

// hardcoded to create Flow/FUSD pool
import FlowToken from "../../../contracts/dependencies/FlowToken.cdc"
import FUSD from "../../../contracts/dependencies/FUSD.cdc"


transaction(id: UInt64, amount: UFix64) {

  // the signers auth account to pass to execute block
  let signer: AuthAccount

  prepare(signer: AuthAccount) {
    self.signer = signer
  }

  execute {
    let farmRef = StakingRewards.borrowFarm(id: 0)!

    let collectionRef = self.signer.borrow<&StakingRewards.StakeControllerCollection>(from: StakingRewards.CollectionStoragePath)
    let stakeControllerRef = collectionRef!.borrow(id: id)!

    farmRef.unstake(amount: amount, stakeControllerRef: stakeControllerRef) 
  }
}


