import FungibleToken from "../../../contracts/dependencies/FungibleToken.cdc"
import FungibleTokens from "../../../contracts/dependencies/FungibleTokens.cdc"
import EmuToken from "../../../contracts/EmuToken.cdc"
import FUSD from "../../../contracts/dependencies/FUSD.cdc"
import EmuSwap from "../../../contracts/exchange/EmuSwap.cdc"

// swap_flow_for_fusd

transaction(amountIn: UFix64) {
  // The Vault references that holds the tokens that are being transferred
  let emuTokenVaultRef: &EmuToken.Vault
  let fusdVaultRef: &FUSD.Vault

  prepare(signer: AuthAccount) {
    self.emuTokenVaultRef = signer.borrow<&EmuToken.Vault>(from: EmuToken.EmuTokenStoragePath)
      ?? panic("Could not borrow a reference to EMU Vault")

    if signer.borrow<&FUSD.Vault>(from: /storage/fusdVault) == nil {
      // Create a new FUSD Vault and put it in storage
      signer.save(<-FUSD.createEmptyVault(), to: /storage/fusdVault)

      // Create a public capability to the Vault that only exposes
      // the deposit function through the Receiver interface
      signer.link<&FUSD.Vault{FungibleToken.Receiver}>(
        /public/fusdReceiver,
        target: /storage/fusdVault
      )

      // Create a public capability to the Vault that only exposes
      // the balance field through the Balance interface
      signer.link<&FUSD.Vault{FungibleToken.Balance}>(
        /public/fusdBalance,
        target: /storage/fusdVault
      )
    }

    self.fusdVaultRef = signer.borrow<&FUSD.Vault>(from: /storage/fusdVault)
      ?? panic("Could not borrow a reference to FUSD Vault")
  }

  execute {    
    let token1Vault <- self.emuTokenVaultRef.withdraw(amount: amountIn) as! @EmuToken.Vault

    let token2Vault <- EmuSwap.borrowPool(id: 1)?.swapToken1ForToken2!(from: <-token1Vault)

    self.fusdVaultRef.deposit(from: <- token2Vault)
  }
}
