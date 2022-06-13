import FungibleToken from "../../contracts/dependencies/FungibleToken.cdc"
import xEmuToken from "../../contracts/xEmuToken.cdc"
import EmuToken from "../../contracts/EmuToken.cdc"

// User deposits xEmuTokens and receives EmuTokens in return

transaction(amount: UFix64) {

  // The Vault resource that holds the tokens being transferred
  let emuVault: @FungibleToken.Vault
  let emuVaultRef: &FungibleToken.Vault

  prepare(signer: AuthAccount) {
    // Get a reference to the signer's stored EmuToken vault
    let vaultRef = signer
      .borrow<&xEmuToken.Vault>(from: xEmuToken.EmuTokenStoragePath)
      ?? panic("Could not borrow reference to the owner's Vault!")
        
    self.emuVaultRef = signer.borrow<&xEmuToken.Vault>(from: xEmuToken.EmuTokenStoragePath)!
    
    // Withdraw tokens from the signer's stored vault
    self.emuVault <- vaultRef.withdraw(amount: amount)
  }

  execute {
    self.emuVaultRef.deposit(from: <- xEmuToken.leavePool(xEmuTokens: <-self.emuVault) )
  }
}