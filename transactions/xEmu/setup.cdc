import FungibleToken from "../../contracts/dependencies/FungibleToken.cdc"
import xEmuToken from "../../contracts/xEmuToken.cdc"

transaction {
  prepare(signer: AuthAccount) {

    let existingVault = signer.borrow<&xEmuToken.Vault>(from: xEmuToken.xEmuTokenVaultStoragePath)

    // If the account is already set up that's not a problem, but we don't want to replace it
    if (existingVault != nil) {
        return
    }
    
    // Create a new FUSD Vault and put it in storage
    signer.save(<-xEmuToken.createEmptyVault(), to: xEmuToken.xEmuTokenVaultStoragePath)

    // Create a public capability to the Vault that only exposes
    // the deposit function through the Receiver interface
    signer.link<&xEmuToken.Vault{FungibleToken.Receiver}>(
      xEmuToken.xEmuTokenReceiverPublicPath,
      target: xEmuToken.xEmuTokenVaultStoragePath
    )

    // Create a public capability to the Vault that only exposes
    // the balance field through the Balance interface
    
    signer.link<&FUSD.Vault{FungibleToken.Balance}>(
      xEmuToken.xEmuTokenBalancePublicPath,
      target: xEmuToken.xEmuTokenVaultStoragePath
    )
    
  }
}