import FungibleToken from "../../contracts/dependencies/FungibleToken.cdc"
import xEmuToken from "../../contracts/xEmuToken.cdc"

transaction {
  prepare(signer: AuthAccount) {

    let existingVault = signer.borrow<&xEmuToken.Vault>(from: xEmuToken.EmuTokenStoragePath)

    // If the account is already set up that's not a problem, but we don't want to replace it
    if (existingVault != nil) {
        return
    }
    
    // Create a new xEmu Vault and put it in storage
    signer.save(<-xEmuToken.createEmptyVault(), to: xEmuToken.EmuTokenStoragePath)

    // Create a public capability to the Vault that only exposes
    // the deposit function through the Receiver interface
    signer.link<&xEmuToken.Vault{FungibleToken.Receiver}>(
      xEmuToken.xEmuTokenReceiverPublicPath,
      target: xEmuToken.EmuTokenStoragePath
    )

    // Create a public capability to the Vault that only exposes
    // the balance field through the Balance interface
    
    signer.link<&xEmuToken.Vault{FungibleToken.Balance}>(
      xEmuToken.xEmuTokenBalancePublicPath,
      target: xEmuToken.EmuTokenStoragePath
    )
    
  }
}