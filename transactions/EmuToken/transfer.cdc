import FungibleToken from "../../contracts/dependencies/FungibleToken.cdc"
import EmuToken from "../../contracts/EmuToken.cdc"

transaction(amount: UFix64, to: Address) {

  // The Vault resource that holds the tokens being transferred
  let sentVault: @FungibleToken.Vault

  prepare(signer: AuthAccount) {
    // Get a reference to the signer's stored vault
    let vaultRef = signer
      .borrow<&EmuToken.Vault>(from: EmuToken.EmuTokenStoragePath)
      ?? panic("Could not borrow reference to the owner's Vault!")

    // Withdraw tokens from the signer's stored vault
    self.sentVault <- vaultRef.withdraw(amount: amount)
  }

  execute {
    // Get the recipient's public account object
    let recipient = getAccount(to)

    // Get a reference to the recipient's Receiver
    let receiverRef = recipient
      .getCapability(EmuToken.EmuTokenReceiverPublicPath)
      .borrow<&{FungibleToken.Receiver}>()
      ?? panic("Could not borrow receiver reference to the recipient's Vault")

    // Deposit the withdrawn tokens in the recipient's receiver
    receiverRef.deposit(from: <-self.sentVault)
  }
}