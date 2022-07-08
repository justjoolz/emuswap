import FungibleToken from "../../../contracts/dependencies/FungibleToken.cdc"
import FungibleTokens from "../../../contracts/dependencies/FungibleTokens.cdc"
import EmuSwap from "../../../contracts/EmuSwap.cdc"

// swap by token by identifier if the pool exists

transaction(fromTokenStorageIdentifier: String, toTokenStorageIdentifier: String, amount: UFix64) {
  // The Vault references that holds the tokens that are being transferred
  let token1VaultRef: &FungibleToken.Vault
  let token2VaultRef: &FungibleToken.Vault
  let poolID: UInt64
  prepare(signer: AuthAccount) {
    self.token1VaultRef = signer.borrow<&FungibleToken.Vault>(from: StoragePath(identifier: fromTokenStorageIdentifier)!)
      ?? panic("Could not borrow a reference to FungibleToken Vault: ".concat(fromTokenStorageIdentifier))

    self.token2VaultRef = signer.borrow<&FungibleToken.Vault>(from: StoragePath(identifier: toTokenStorageIdentifier)!)
      ?? panic("Could not borrow a reference to FungibleToken Vault: ".concat(toTokenStorageIdentifier))

    let token1Identifier = self.token1VaultRef.getType().identifier
    let token2Identifier = self.token2VaultRef.getType().identifier
   
    self.poolID = EmuSwap.getPoolIDFromIdentifiers(token1: token1Identifier, token2: token2Identifier) ?? panic("Can't find swap pool for ".concat(token1Identifier).concat(" and ".concat(token2Identifier)))
    
  }

  execute {    
    let token1Vault <- self.token1VaultRef.withdraw(amount: amount)
    let token2Vault <- EmuSwap.borrowPool(id: self.poolID)?.swapTokens!(from: <-token1Vault)
    self.token2VaultRef.deposit(from: <- token2Vault)
  }
}
