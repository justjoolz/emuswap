// create_new_pool.cd 
//
// This transaction creates a new Flow/FUSD pool..... 

import FungibleToken from "../../../contracts/dependencies/FungibleToken.cdc"
import FungibleTokens from "../../../contracts/dependencies/FungibleTokens.cdc"
import EmuSwap from "../../../contracts/exchange/EmuSwap.cdc"

// hardcoded to create Flow/FUSD pool
import FlowToken from "../../../contracts/dependencies/FlowToken.cdc"
import FiatToken from "../../../contracts/dependencies/FiatToken.cdc"


transaction(token1Amount: UFix64, token2Amount: UFix64) {

  // The Vault references that holds the tokens that are being transferred
  let flowTokenVaultRef: &FlowToken.Vault
  let usdcVaultRef: &FiatToken.Vault

  // EmuSwap Admin Ref
  let adminRef: &EmuSwap.Admin
  
  // new pool to deposit to collection
  let lpTokenVault: @EmuSwap.TokenVault

  // reference to lp collection
  let lpCollectionRef: &EmuSwap.Collection


  let signer: AuthAccount

  prepare(signer: AuthAccount) {
    
    // prepare tokens refernces to withdraw inital liquidity 
    self.flowTokenVaultRef = signer.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
        ?? panic("Could not borrow a reference to Vault")

    self.usdcVaultRef = signer.borrow<&FiatToken.Vault>(from: FiatToken.VaultStoragePath)
        ?? panic("Could not borrow a reference to FiatToken Vault (USDC)")

    // Create new Pool Vault 
    self.lpTokenVault <-EmuSwap.createEmptyTokenVault(tokenID: EmuSwap.nextPoolID) //to: EmuSwap.LPTokensStoragePath
    
    // check if Collection is created if not then create
    if signer.borrow<&EmuSwap.Collection>(from: EmuSwap.LPTokensStoragePath) == nil {
      // Create a new Collection and put it in storage
      signer.save(<- EmuSwap.createEmptyCollection(), to: EmuSwap.LPTokensStoragePath)
      
      /*
      // Create a public capability to the Collection that only exposes
      signer.link<&EmuSwap.Collection{FungibleTokens.CollectionPublic}>(
        EmuSwap.LPTokensPublicReceiverPath,
        target: EmuSwap.LPTokensStoragePath
      )
       */
      
    }
    self.lpCollectionRef = signer.borrow<&EmuSwap.Collection>(from: EmuSwap.LPTokensStoragePath)!

    self.adminRef = signer.borrow<&EmuSwap.Admin>(from: EmuSwap.AdminStoragePath)
      ?? panic("Could not borrow a reference to EmuSwap Admin")

    self.signer = signer
  }

  execute {
    // Withdraw tokens
    let token1Vault <- self.flowTokenVaultRef.withdraw(amount: token1Amount) as! @FlowToken.Vault
    let token2Vault <- self.usdcVaultRef.withdraw(amount: token2Amount) as! @FiatToken.Vault

    // Provide liquidity and get liquidity provider tokens
    let tokenBundle <- EmuSwap.createTokenBundle(fromToken1: <- token1Vault, fromToken2: <- token2Vault)

    // Keep the liquidity provider tokens
    let lpTokens <- self.adminRef.createNewLiquidityPool(from: <- tokenBundle)
    self.adminRef.togglePoolFreeze(id: lpTokens.tokenID)
  
    // deposit new lp tokens in local vault
    self.lpTokenVault.deposit(from: <-lpTokens )

    // deposit to collection in storage
    self.lpCollectionRef.deposit(token: <- self.lpTokenVault)
    //self.signer.save(<- lpTokens, to: /storage/LPToken)
  }
}