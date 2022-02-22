// create_new_pool.cd 
//
// This transaction creates a new Flow/FUSD pool..... 

import FungibleToken from "../../../contracts/dependencies/FungibleToken.cdc"
import FungibleTokens from "../../../contracts/dependencies/FungibleTokens.cdc"
import EmuSwap from "../../../contracts/exchange/EmuSwap.cdc"

// hardcoded to create Flow/FUSD pool
import FlowToken from "../../../contracts/dependencies/FlowToken.cdc"
import FUSD from "../../../contracts/dependencies/FUSD.cdc"


transaction(token1Amount: UFix64, token2Amount: UFix64) {

  // The Vault references that holds the tokens that are being transferred
  let flowTokenVaultRef: &FlowToken.Vault
  let fusdVaultRef: &FUSD.Vault

  // EmuSwap Admin Ref
  let adminRef: &EmuSwap.Admin
  
  // new pool to deposit to collection
  let lpTokenVault: @EmuSwap.TokenVault

  // reference to lp collection
  let lpCollectionRef: &EmuSwap.Collection


  // the signers auth account to pass to execute block
  let signer: AuthAccount

  prepare(signer: AuthAccount) {
    
    // prepare tokens refernces to withdraw inital liquidity 
    self.flowTokenVaultRef = signer.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
        ?? panic("Could not borrow a reference to Vault")

    self.fusdVaultRef = signer.borrow<&FUSD.Vault>(from: /storage/fusdVault)
        ?? panic("Could not borrow a reference to fusd Vault")

    // Create new Pool Vault 
    self.lpTokenVault <-EmuSwap.createEmptyTokenVault(tokenID: EmuSwap.nextPoolID) //to: EmuSwap.LPTokensStoragePath
    
    // check if Collection is created if not then create
    if signer.borrow<&EmuSwap.Collection>(from: EmuSwap.LPTokensStoragePath) == nil {
      // Create a new Collection and put it in storage
      signer.save(<- EmuSwap.createEmptyCollection(), to: EmuSwap.LPTokensStoragePath)
      
      
    }
    self.lpCollectionRef = signer.borrow<&EmuSwap.Collection>(from: EmuSwap.LPTokensStoragePath)!

    self.adminRef = signer.borrow<&EmuSwap.Admin>(from: EmuSwap.AdminStoragePath)
      ?? panic("Could not borrow a reference to EmuSwap Admin")

    self.signer = signer
  }

  execute {
    // Withdraw tokens
    let token1Vault <- self.flowTokenVaultRef.withdraw(amount: token1Amount) as! @FlowToken.Vault
    let token2Vault <- self.fusdVaultRef.withdraw(amount: token2Amount) as! @FUSD.Vault

    // Provide liquidity and get liquidity provider tokens
    let tokenBundle <- EmuSwap.createTokenBundle(fromToken1: <- token1Vault, fromToken2: <- token2Vault)

    // Keep the liquidity provider tokens
    let lpTokens <- self.adminRef.createNewLiquidityPool(from: <- tokenBundle)

    self.adminRef.togglePoolFreeze(id: lpTokens.tokenID)
  
    self.lpTokenVault.deposit(from: <-lpTokens )
    self.lpCollectionRef.deposit(token: <- self.lpTokenVault)
    //self.signer.save(<- lpTokens, to: /storage/LPToken)
  }
}
