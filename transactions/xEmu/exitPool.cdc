import FungibleToken from "../../contracts/dependencies/FungibleToken.cdc"
import xEmuToken from "../../contracts/xEmuToken.cdc"
import EmuToken from "../../contracts/EmuToken.cdc"

// User deposits xEmuTokens and receives EmuTokens in return

transaction(amount: UFix64) {

  // The Vault resource that holds the tokens being transferred
  let xEmuVault: @FungibleToken.Vault
  let emuVaultRef: &FungibleToken.Vault

  prepare(signer: AuthAccount) {
    // Get a reference to the signer's stored XEmuToken vault
    let XEmuVaultRef = signer
      .borrow<&xEmuToken.Vault>(from: xEmuToken.EmuTokenStoragePath)
      ?? panic("Could not borrow reference to the owner's Vault!")
    // Withdraw tokens from the signer's stored vault
    self.xEmuVault <- XEmuVaultRef.withdraw(amount: amount)

    // borrow users EmuToken Vault to deposit into
    self.emuVaultRef = signer.borrow<&EmuToken.Vault>(from: EmuToken.EmuTokenStoragePath)!
  }

  execute {
    self.emuVaultRef.deposit(from: <- xEmuToken.leavePool(xEmuTokens: <-self.xEmuVault) )
  }
}