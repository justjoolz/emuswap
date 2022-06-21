import FungibleToken from "../../../contracts/dependencies/FungibleToken.cdc"
import FungibleTokens from "../../../contracts/dependencies/FungibleTokens.cdc"
import EmuToken from "../../../contracts/EmuToken.cdc"
import FUSD from "../../../contracts/dependencies/FUSD.cdc"
import EmuSwap from "../../../contracts/EmuSwap.cdc"

transaction(fromPool: UInt64, amount: UFix64, storageIdentifierA: String, storageIdentifierB: String) {
  // LP Tokens Collection ref
  let lpTokensCollection: &EmuSwap.Collection

  // The TokenVault reference for withdrawing liquidity tokens
  let liquidityTokenRef: &FungibleTokens.TokenVault

  // The pool reference to withdraw liquidity from
  let pool: &EmuSwap.Pool

  // The Vault references that holds the tokens that are being removed from the pool
  let vault1ref: &FungibleToken.Vault
  let vault2ref: &FungibleToken.Vault

  prepare(signer: AuthAccount) {
    self.lpTokensCollection = signer.borrow<&EmuSwap.Collection>(from: EmuSwap.LPTokensStoragePath)
      ?? panic("Could not borrow reference to signers LP Tokens collection")

    self.liquidityTokenRef = self.lpTokensCollection.borrowVault(id: fromPool)

    self.pool = EmuSwap.borrowPool(id: fromPool)
      ?? panic("Could not borrow pool")

    self.vault1ref = signer.borrow<&FungibleToken.Vault>(from: StoragePath(identifier: storageIdentifierA)!)
     ?? panic("Could not borrow a reference to FungibleToken Vault: ".concat(storageIdentifierA))

    self.vault2ref = signer.borrow<&FungibleToken.Vault>(from: StoragePath(identifier: storageIdentifierB)!)
      ?? panic("Could not borrow a reference to FungibleToken Vault: ".concat(storageIdentifierB))
  }

  execute {
    // Withdraw liquidity provider tokens from Pool
    let liquidityTokenVault <- self.liquidityTokenRef.withdraw(amount: amount) as! @EmuSwap.TokenVault

    // Take back liquidity
    let tokenBundle <- self.pool.removeLiquidity(from: <- liquidityTokenVault)

    // Deposit liquidity tokens
    self.vault1ref.deposit(from: <- tokenBundle.withdrawToken1())
    self.vault2ref.deposit(from: <- tokenBundle.withdrawToken2())

    destroy tokenBundle
  }
}
