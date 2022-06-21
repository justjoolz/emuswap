// create_new_pool.cd 
//
// This transaction creates a new reward pool from a path to a fungible token

// Currently Hardcoded to use Decaying Emission as per EmuToken but can be customized to any requirements
 
import StakingRewards from "../../../contracts/StakingRewards.cdc"
import FungibleToken from "../../../contracts/dependencies/FungibleToken.cdc"
import NonFungibleToken from "../../../contracts/dependencies/NonFungibleToken.cdc"

transaction(storageID: String, amount: UFix64, nftPaths: [String]) {

  let adminRef: &StakingRewards.Admin
  let tokens: @FungibleToken.Vault

  prepare(signer: AuthAccount) {
    self.adminRef = signer.borrow<&StakingRewards.Admin>(from: StakingRewards.AdminStoragePath) ?? panic("Cannot borrow Staking rewards admin")

    let vaultRef = signer.borrow<&FungibleToken.Vault>(from: StoragePath(identifier: storageID)!)
      ?? panic("Could not borrow reference to the owner's Vault!")
    
    self.tokens <- vaultRef.withdraw(amount: amount)
  }

  execute {
    
    let emissionDetails = StakingRewards.DecayingEmission(
        epochLength: 28.0 * 24.0 * 60.0 * 60.0,
        totalEpochs: 40.0, 
        decay: 0.05388176 * 2.0 // twice the decay = half the emission rate of the EMU pool....
    ) 

    self.adminRef.createRewardPool(
      tokens: <- self.tokens,  
      emissionDetails: emissionDetails,
      farmWeightsByID: {0: 1.0},
      accessNFTsAccepted: nftPaths
    )
  }      
}
