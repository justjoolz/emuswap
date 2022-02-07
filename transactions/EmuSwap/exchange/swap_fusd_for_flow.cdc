import FungibleToken from "../../../contracts/dependencies/FungibleToken.cdc"
import FungibleTokens from "../../../contracts/dependencies/FungibleTokens.cdc"
import FlowToken from "../../../contracts/dependencies/FlowToken.cdc"
import FUSD from "../../../contracts/dependencies/FUSD.cdc"
import EmuSwap from "../../../contracts/exchange/EmuSwap.cdc"

// swap_fusd_for_flow

transaction(amountIn: UFix64) {
  // The Vault references that holds the tokens that are being transferred
  let flowTokenVaultRef: &FlowToken.Vault
  let fusdVaultRef: &FUSD.Vault

  let poolRef: &EmuSwap.Pool

  prepare(signer: AuthAccount) {
    self.fusdVaultRef = signer.borrow<&FUSD.Vault>(from: /storage/fusdVault)
      ?? panic("Could not borrow a reference to FUSD Vault")

    self.flowTokenVaultRef = signer.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
      ?? panic("Could not borrow a reference to FLOW Vault")

    self.poolRef = EmuSwap.borrowPool(id: 0) 
      ?? panic("could not borrow pool ref") 
  }

  execute {    
    
    self.poolRef.getPoolAmounts()
    /*
    let token2Vault <- self.fusdVaultRef.withdraw(amount: amountIn) as! @FUSD.Vault

    let token1Vault <- self.poolRef.swapToken2ForToken1(from: <-token2Vault)

    self.flowTokenVaultRef.deposit(from: <- token1Vault)
     */
  }
}
