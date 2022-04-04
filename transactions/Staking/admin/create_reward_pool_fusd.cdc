// create_new_pool.cd 
//
// This transaction creates a new reward pool from a path to a fungible token
// j00lz 2do grab reference from a sample NFT to make NFT gated reward pool 

import StakingRewards from "../../../contracts/StakingRewards.cdc"
import FungibleToken from "../../../contracts/dependencies/FungibleToken.cdc"
import NonFungibleToken from "../../../contracts/dependencies/NonFungibleToken.cdc"

transaction(amount: UFix64) {

  let adminRef: &StakingRewards.Admin
  let tokens: @FungibleToken.Vault

  prepare(signer: AuthAccount) {
    self.adminRef = signer.borrow<&StakingRewards.Admin>(from: StakingRewards.AdminStoragePath) ?? panic("Cannot borrow Staking rewards admin")

    // test storage paths.... currently not working :/ 
    let fusdPath = "/storage/fusdVault"
    let flowPath = "/storage/flowTokenVault"

    log(fusdPath)
    log(StoragePath(identifier: fusdPath))

    let vaultRef = signer.borrow<&FungibleToken.Vault>(from: /storage/fusdVault)
      ?? panic("Could not borrow reference to the owner's Vault!")
    
    self.tokens <- vaultRef.withdraw(amount: amount)
  }

  execute {
    
    let emissionDetails = StakingRewards.DecayingEmission(
        epochLength: 28.0 * 24.0 * 60.0 * 60.0,
        totalEpochs: 40.0, 
        decay: 0.05388176 * 2.0 // twice the decay = half the emission of the EMU pool....
    ) 

    self.adminRef.createRewardPool(
      tokens: <- self.tokens,  
      emissionDetails: emissionDetails,
      farmWeightsByID: {0: 1.0},
      accessNFTsAccepted: []
    )
  }      
}
