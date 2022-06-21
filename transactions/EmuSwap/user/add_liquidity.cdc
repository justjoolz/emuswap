import FungibleToken from "../../../contracts/dependencies/FungibleToken.cdc"
import FungibleTokens from "../../../contracts/dependencies/FungibleTokens.cdc"
import EmuSwap from "../../../contracts/EmuSwap.cdc"

transaction(token1Path: String, token1Amount: UFix64, token2Path: String, token2Amount: UFix64) {
  
  let poolID:UInt64

  // The Vault references that holds the tokens that are being added as liquidity
  let token1VaultRef: &FungibleToken.Vault
  let token2VaultRef: &FungibleToken.Vault

  // reference to lp collection
  var lpCollectionRef: &EmuSwap.Collection

  // The Vault reference for liquidity tokens
  var liquidityTokenRef: &FungibleTokens.TokenVault

  prepare(signer: AuthAccount) {

    self.token1VaultRef = signer.borrow<&FungibleToken.Vault>(from: StoragePath(identifier: token1Path)!)
        ?? panic("Could not borrow a reference to Vault ".concat(token1Path))

    self.token2VaultRef = signer.borrow<&FungibleToken.Vault>(from: StoragePath(identifier: token2Path)!)
        ?? panic("Could not borrow a reference to Vault ".concat(token2Path))
    
    let token1Identifier = self.token1VaultRef.getType().identifier
    let token2Identifier = self.token2VaultRef.getType().identifier
    
    self.poolID = EmuSwap.getPoolIDFromIdentifiers(token1: token1Identifier, token2: token2Identifier) ?? panic("Can't find swap pool for ".concat(token1Identifier).concat(" and ".concat(token2Identifier)))

     // check if Collection is created if not then create
    if signer.borrow<&EmuSwap.Collection>(from: EmuSwap.LPTokensStoragePath) == nil {
      // Create a new Collection and put it in storage
      signer.save(<- EmuSwap.createEmptyCollection(), to: EmuSwap.LPTokensStoragePath)
      signer.link<&EmuSwap.Collection{FungibleTokens.CollectionPublic}>(
        EmuSwap.LPTokensPublicReceiverPath, 
        target: EmuSwap.LPTokensStoragePath
      )
    }

    // store reference to LP Tokens Collection
    self.lpCollectionRef = signer.borrow<&EmuSwap.Collection>(from: EmuSwap.LPTokensStoragePath)!

    // check if the user has the correct LP in their collection
    if !self.lpCollectionRef.getIDs().contains(self.poolID) {
      // if not create an empty LP Token
      let tokenVault <- EmuSwap.createEmptyTokenVault(tokenID: self.poolID)
      self.lpCollectionRef.deposit(token: <-tokenVault)
      self.liquidityTokenRef = self.lpCollectionRef.borrowVault(id: self.poolID)
    }
    
    self.liquidityTokenRef = self.lpCollectionRef.borrowVault(id: self.poolID)
  }

  execute {
    // Withdraw tokens
    let token1Vault <- self.token1VaultRef.withdraw(amount: token1Amount)
    let token2Vault <- self.token2VaultRef.withdraw(amount: token2Amount)

    // create a token bundle with both tokens in equal measure
    let tokenBundle <- EmuSwap.createTokenBundle(fromToken1: <- token1Vault, fromToken2: <- token2Vault)
    
    // Pass tokenbundle to add liquidity and get LP tokens in return
    let liquidityTokenVault <- EmuSwap.borrowPool(id: self.poolID)?.addLiquidity!(from: <- tokenBundle)

    // Deposit the liquidity provider tokens
    self.liquidityTokenRef.deposit(from: <- liquidityTokenVault)
  }
}
