import FungibleToken from "../../../contracts/dependencies/FungibleToken.cdc"
import FungibleTokens from "../../../contracts/dependencies/FungibleTokens.cdc"
import EmuToken from "../../../contracts/EmuToken.cdc"
import FUSD from "../../../contracts/dependencies/FUSD.cdc"
import EmuSwap from "../../../contracts/exchange/EmuSwap.cdc"

// Currently hardcoded to withdraw from pool id: 0

transaction(amount: UFix64) {
  // LP Tokens Collection ref
  let lpTokensCollection: &EmuSwap.Collection

  // The TokenVault reference for withdrawing liquidity tokens
  let liquidityTokenRef: &FungibleTokens.TokenVault

  // The pool reference to withdraw liquidity from
  let pool: &EmuSwap.Pool

  // The Vault references that holds the tokens that are being removed from the pool
  let emuTokenVaultRef: &EmuToken.Vault
  let fusdVaultRef: &FUSD.Vault

  prepare(signer: AuthAccount) {
    self.lpTokensCollection = signer.borrow<&EmuSwap.Collection>(from: EmuSwap.LPTokensStoragePath)
      ?? panic("Could not borrow reference to signers LP Tokens collection")

    self.liquidityTokenRef = self.lpTokensCollection.borrowVault(id: 1)

    self.pool = EmuSwap.borrowPool(id: 1)
      ?? panic("Could not borrow pool")

    self.emuTokenVaultRef = signer.borrow<&EmuToken.Vault>(from: EmuToken.EmuTokenStoragePath)
      ?? panic("Could not borrow a reference to EmuToken Vault")

    self.fusdVaultRef = signer.borrow<&FUSD.Vault>(from: /storage/fusdVault)
      ?? panic("Could not borrow a reference to FUSD Vault")
  }

  execute {
    // Withdraw liquidity provider tokens from Pool
    let liquidityTokenVault <- self.liquidityTokenRef.withdraw(amount: amount) as! @EmuSwap.TokenVault

    // Take back liquidity
    let tokenBundle <- self.pool.removeLiquidity(from: <- liquidityTokenVault)

    // Deposit liquidity tokens
    self.emuTokenVaultRef.deposit(from: <- tokenBundle.withdrawToken1())
    self.fusdVaultRef.deposit(from: <- tokenBundle.withdrawToken2())

    destroy tokenBundle
  }
}
