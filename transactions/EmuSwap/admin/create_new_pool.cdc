// create_new_pool.cd 
//

import FungibleToken from "../../../contracts/dependencies/FungibleToken.cdc"
import FungibleTokens from "../../../contracts/dependencies/FungibleTokens.cdc"
import EmuSwap from "../../../contracts/EmuSwap.cdc"

transaction(token1Storage: String, token1Amount: UFix64, token2Storage: String, token2Amount: UFix64) {

  // The Vault references that holds the tokens that are being transferred
  let vaultA: &FungibleToken.Vault
  let vaultB: &FungibleToken.Vault

  // EmuSwap Admin Ref
  let adminRef: &EmuSwap.Admin
  
  // reference to lp collection
  let lpCollectionRef: &EmuSwap.Collection

  let signer: AuthAccount

  prepare(signer: AuthAccount) {
    
    // prepare tokens refernces to withdraw inital liquidity 
    self.vaultA = signer.borrow<&FungibleToken.Vault>(from: StoragePath(identifier: token1Storage)!)
        ?? panic("Could not borrow a reference to Vault A: ".concat(token1Storage))

    self.vaultB = signer.borrow<&FungibleToken.Vault>(from: StoragePath(identifier: token2Storage)!)
        ?? panic("Could not borrow a reference to Vault B: ".concat(token2Storage))

    // check if Collection is created if not then create
    if signer.borrow<&EmuSwap.Collection>(from: EmuSwap.LPTokensStoragePath) == nil {
      // Create a new Collection and put it in storage
      signer.save(<- EmuSwap.createEmptyCollection(), to: EmuSwap.LPTokensStoragePath)
      
      // Create a public capability to the Collection that only exposes
      signer.link<&EmuSwap.Collection{FungibleTokens.CollectionPublic}>(
        EmuSwap.LPTokensPublicReceiverPath,
        target: EmuSwap.LPTokensStoragePath
      )
      
    }
    self.lpCollectionRef = signer.borrow<&EmuSwap.Collection>(from: EmuSwap.LPTokensStoragePath)!

    self.adminRef = signer.borrow<&EmuSwap.Admin>(from: EmuSwap.AdminStoragePath)
      ?? panic("Could not borrow a reference to EmuSwap Admin")

    self.signer = signer
  }

  execute {
    // Withdraw tokens
    let token1Vault <- self.vaultA.withdraw(amount: token1Amount) as! @FungibleToken.Vault
    let token2Vault <- self.vaultB.withdraw(amount: token2Amount) as! @FungibleToken.Vault

    // Provide liquidity and get liquidity provider tokens
    let tokenBundle <- EmuSwap.createTokenBundle(fromToken1: <- token1Vault, fromToken2: <- token2Vault)

    // Keep the liquidity provider tokens
    let lpTokens <- self.adminRef.createNewLiquidityPool(from: <- tokenBundle)
    
    // j00lz 2do remove from production (and update tests)
    self.adminRef.togglePoolFreeze(id: lpTokens.tokenID)
    
    self.lpCollectionRef.deposit(token: <- lpTokens)
  }
}
