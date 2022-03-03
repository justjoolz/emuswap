// create_new_pool.cd 
//
// This transaction creates a new Flow/FUSD pool..... 

import FungibleToken from "../../../contracts/dependencies/FungibleToken.cdc"
import FungibleTokens from "../../../contracts/dependencies/FungibleTokens.cdc"
import EmuSwap from "../../../contracts/exchange/EmuSwap.cdc"

// hardcoded to create EMU/FUSD pool
import FUSD from "../../../contracts/dependencies/FUSD.cdc"
import EmuToken from "../../../contracts/EmuToken.cdc"


transaction(token1Amount: UFix64, token2Amount: UFix64) {

  // The Vault references that holds the tokens that are being transferred
  let emuTokenVaultRef: &EmuToken.Vault
  let fusdVaultRef: &FUSD.Vault

  // EmuSwap Admin Ref
  let adminRef: &EmuSwap.Admin
  
  // new pool to deposit to collection
  let lpTokenVault: @EmuSwap.TokenVault

  // reference to lp collection
  let lpCollectionRef: &EmuSwap.Collection

  // The Vault reference for liquidity tokens
  //let liquidityTokenRef: &EmuSwap.Vault

  // the signers auth account to pass to execute block
  let signer: AuthAccount

  prepare(signer: AuthAccount) {
    
    // prepare tokens refernces to withdraw inital liquidity 
    self.emuTokenVaultRef = signer.borrow<&EmuToken.Vault>(from: EmuToken.EmuTokenStoragePath)
        ?? panic("Could not borrow a reference to Vault")

    self.fusdVaultRef = signer.borrow<&FUSD.Vault>(from: /storage/fusdVault)
        ?? panic("Could not borrow a reference to fusd Vault")

    // Create new Pool Vault 
    self.lpTokenVault <-EmuSwap.createEmptyTokenVault(tokenID: EmuSwap.nextPoolID) //to: EmuSwap.LPTokensStoragePath
    
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
    let token1Vault <- self.emuTokenVaultRef.withdraw(amount: token1Amount) as! @EmuToken.Vault
    let token2Vault <- self.fusdVaultRef.withdraw(amount: token2Amount) as! @FUSD.Vault

    // Provide liquidity and get liquidity provider tokens
    let tokenBundle <- EmuSwap.createTokenBundle(fromToken1: <- token1Vault, fromToken2: <- token2Vault)

    // Keep the liquidity provider tokens
    let lpTokens <- self.adminRef.createNewLiquidityPool(from: <- tokenBundle)
    self.adminRef.togglePoolFreeze(id: lpTokens.tokenID)
  
    self.lpTokenVault.deposit(from: <-lpTokens )
    self.lpCollectionRef.deposit(token: <- self.lpTokenVault)
  }
}
