import FungibleToken from "../../contracts/dependencies/FungibleToken.cdc"
import EmuToken from "../../contracts/EmuToken.cdc"

transaction {
  prepare(signer: AuthAccount) {

    let existingVault = signer.borrow<&EmuToken.Vault>(from: EmuToken.EmuTokenStoragePath)

    // If the account is already set up that's not a problem, but we don't want to replace it
    if (existingVault != nil) {
        return
    }
    
    // Create a new FUSD Vault and put it in storage
    signer.save(<-EmuToken.createEmptyVault(), to: EmuToken.EmuTokenStoragePath)

    // Create a public capability to the Vault that only exposes
    // the deposit function through the Receiver interface
    signer.link<&EmuToken.Vault{FungibleToken.Receiver}>(
      EmuToken.EmuTokenReceiverPublicPath,
      target: EmuToken.EmuTokenStoragePath
    )

    // Create a public capability to the Vault that only exposes
    // the balance field through the Balance interface
    
    signer.link<&EmuToken.Vault{FungibleToken.Balance}>(
      EmuToken.EmuTokenBalancePublicPath,
      target: EmuToken.EmuTokenStoragePath
    )
    
  }
}