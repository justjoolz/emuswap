/*
███████╗░███╗░░░███╗░██╗░░░██╗░░░██████╗░██╗░░░░░░░██╗░█████╗░██████╗░
██╔════╝░████╗░████║░██║░░░██║░░██╔════╝░██║░░██╗░░██║██╔══██╗██╔══██╗
█████╗░░░██╔████╔██║░██║░░░██║░░╚█████╗░░╚██╗████╗██╔╝███████║██████╔╝
██╔══╝░░░██║╚██╔╝██║░██║░░░██║░░░╚═══██╗░░████╔═████║░██╔══██║██╔═══╝░
███████╗░██║░╚═╝░██║░╚██████╔╝░░██████╔╝░░╚██╔╝░╚██╔╝░██║░░██║██║░░░░░
╚══════╝░╚═╝░░░░░╚═╝░░╚═════╝░░░╚═════╝░░░░╚═╝░░░╚═╝░░╚═╝░░╚═╝╚═╝░░░░░
*/

import FungibleToken from "../dependencies/FungibleToken.cdc"
import FungibleTokens from "../dependencies/FungibleTokens.cdc"
// import FungibleTokens from "../dependencies/FungibleTokens.cdc"

pub contract EmuSwap: FungibleTokens {
  
  // Pools kept here and only accessible via the contract (could make account to allow for future ideas?)
  access(contract) var poolsByID: @{UInt64: Pool}
  
  // Total supply of liquidity tokens in existence
  access(contract) var totalSupplyByID: {UInt64: UFix64}

  //  unique ID for each pool
  pub var nextPoolID: UInt64

  // Defines token vault storage path
  pub let LPTokensStoragePath: StoragePath

  // Defines token vault public balance path
  pub let LPTokensPublicBalancePath: PublicPath

  // Defines token vault public receiver path
  pub let LPTokensPublicReceiverPath: PublicPath

  pub let AdminStoragePath: StoragePath

  // Event that is emitted when the contract is deployed
  pub event ContractInitialized()
  
  // Event emitted when a new LP token is initalized
  pub event TokensInitialized(tokenID: UInt64)

  // Event that is emitted when tokens are withdrawn from a Vault
  pub event TokensWithdrawn(tokenID: UInt64, amount: UFix64, from: Address?)

  // Event that is emitted when tokens are deposited to a Vault
  pub event TokensDeposited(tokenID: UInt64, amount: UFix64, to: Address?)

  // Event that is emitted when new tokens are minted
  // Liquidity added to pool
  pub event TokensMinted(tokenID: UInt64, amount: UFix64)

  // Event that is emitted when tokens are destroyed
  // Liquidity withdrawn from pool
  pub event TokensBurned(tokenID: UInt64, amount: UFix64)

  // Event that is emitted when trading fee is updated
  pub event FeeUpdated(feePercentage: UFix64)

  // j00lz can make this event more specific from: and to: with amounts and Type.identifier or maybe poolID
  pub event Trade(token1Amount: UFix64, token2Amount: UFix64, side: UInt8)
  
  // j00lz add Pool creation details (how is this different from new LP token creation?)
  pub event NewSwapPoolCreated()

  // TokenVault
  //
  // The LP Tokens issued are stored in a TokenVault
  pub resource TokenVault: FungibleTokens.Provider, FungibleTokens.Receiver, FungibleTokens.Balance {

    // holds the balance of a users tokens
    pub var balance: UFix64
    pub let tokenID: UInt64

    // initialize the tokenID and balance at resource creation time
    init(tokenID: UInt64, balance: UFix64) {
      self.tokenID = tokenID
      self.balance = balance
    }

    // withdraw
    //
    pub fun withdraw(amount: UFix64): @FungibleTokens.TokenVault {
      self.balance = self.balance - amount
      emit TokensWithdrawn(tokenID: self.tokenID, amount: amount, from: self.owner?.address)
      return <- create TokenVault(tokenID: self.tokenID, balance: amount)
    }

    // deposit
    //
    pub fun deposit(from: @FungibleTokens.TokenVault) {
      let vault <- from as! @EmuSwap.TokenVault
      self.balance = self.balance + vault.balance
      emit TokensDeposited(tokenID: self.tokenID, amount: vault.balance, to: self.owner?.address)
      vault.balance = 0.0
      destroy vault
    }

    destroy() {
      EmuSwap.totalSupplyByID[self.tokenID] = EmuSwap.totalSupplyByID[self.tokenID]! - self.balance
    }
  }

  // createEmptyTokenVault
  //
  pub fun createEmptyTokenVault(tokenID: UInt64): @EmuSwap.TokenVault {
    return <-create TokenVault(tokenID: tokenID, balance: 0.0)
  }

  pub resource TokenBundle {
    pub var token1: @FungibleToken.Vault
    pub var token2: @FungibleToken.Vault

    // initialize the vault bundle
    init(fromToken1: @FungibleToken.Vault, fromToken2: @FungibleToken.Vault) {
      self.token1 <- fromToken1
      self.token2 <- fromToken2
    }

    pub fun depositToken1(from: @FungibleToken.Vault) {
      self.token1.deposit(from: <- from)
    }

    pub fun depositToken2(from: @FungibleToken.Vault) {
      self.token2.deposit(from: <- from)
    }

    pub fun withdrawToken1(): @FungibleToken.Vault {
      return <- self.token1.withdraw(amount: self.token1.balance)
    }

    pub fun withdrawToken2(): @FungibleToken.Vault {
      return <- self.token2.withdraw(amount: self.token2.balance)
    }

    destroy() {
      destroy self.token1
      destroy self.token2
    }
  }

  // createTokenBundle
  //
  pub fun createTokenBundle(fromToken1: @FungibleToken.Vault, fromToken2: @FungibleToken.Vault): @EmuSwap.TokenBundle {
    return <- create TokenBundle(fromToken1: <- fromToken1, fromToken2: <- fromToken2)
  }

  // mintTokens
  //
  // Function that mints new tokens, adds them to the total supply,
  // and returns them to the calling context.
  //
  access(contract) fun mintTokens(tokenID: UInt64, amount: UFix64): @EmuSwap.TokenVault {
    pre {
      amount > UFix64(0): "Amount minted must be greater than zero"
    }
    if EmuSwap.totalSupplyByID[tokenID] == nil {
      EmuSwap.totalSupplyByID[tokenID] = amount
    } else {
      EmuSwap.totalSupplyByID[tokenID] = EmuSwap.totalSupplyByID[tokenID]! + amount
    }
    emit TokensMinted(tokenID: tokenID, amount: amount)
    return <-create TokenVault(tokenID: tokenID, balance: amount)
  }

  // burnTokens
  //
  // Function that destroys a Vault instance, effectively burning the tokens.
  //
  // Note: the burned tokens are automatically subtracted from the 
  // total supply in the Vault destructor.
  //
  access(contract) fun burnTokens(from: @EmuSwap.TokenVault) {
    let vault <- from as! @EmuSwap.TokenVault
    let amount = vault.balance
    let tokenID = vault.tokenID
    destroy vault
    emit TokensBurned(tokenID: tokenID, amount: amount)
  }

  pub resource Admin {

    pub fun togglePoolFreeze(id: UInt64) {
      let poolRef = &EmuSwap.poolsByID[id] as &Pool
      poolRef.togglePoolFreeze()
    }

    pub fun createNewLiquidityPool(from: @EmuSwap.TokenBundle): @EmuSwap.TokenVault {
      /*
        let token1Vault <- from.withdrawToken1()
        let token2Vault <- from.withdrawToken2()
        
        assert(token1Vault.balance > UFix64(0), message: "Empty token1 vault")
        assert(token2Vault.balance > UFix64(0), message: "Empty token2 vault")
        */

        // j00lz notes: 1) shouldn't have to do the if == nil destroy else deposit dance.... 
        // this is configured to add to the contract.... which is outdated now.... business logic should be moved to the Pool itself.... 
        
        // now instead need to
        // create Pool() 
        // addLiquidity / donateLiquidity     *(donate == perma locked liquidity :)
        /*
        if token1Vault == nil {
          destroy token1Vault
        } else {
          EmuSwap.token1Vault?.deposit(from: <- token1Vault)
        }

        if token2Vault == nil {
          destroy token2Vault
        } else {
          EmuSwap.token2Vault?.deposit(from: <- token2Vault)
        }

        destroy from
       */

      // j00lz 2DO .... need to check pool doesn't already exist! (both 1->2 and 2->1 equivalent tokenBundles)
      
      // create new pool
      let newPool <- create Pool()
      
      // drop liquidity in
      newPool.donateLiquidity(from: <- from)

      // Add new Pool to dictionary
      EmuSwap.poolsByID[EmuSwap.nextPoolID] <-! newPool

      log(EmuSwap.poolsByID[EmuSwap.nextPoolID]?.getPoolMeta())

      // Create initial tokens
      let lpTokens <- EmuSwap.mintTokens(tokenID: EmuSwap.nextPoolID, amount: 1.0)

      // increment ready for next new pool
      EmuSwap.nextPoolID = EmuSwap.nextPoolID + 1
      
      // j00lz add details to event
      emit NewSwapPoolCreated()

      return <- lpTokens
    }
  
  }

  // PoolMeta
  //
  pub struct PoolMeta {
    pub let token1Amount: UFix64
    pub let token2Amount: UFix64

    pub let token1Identifier: String
    pub let token2Identifier: String

    init(poolRef: &Pool) {
      self.token1Amount = poolRef.token1Vault?.balance!
      self.token2Amount = poolRef.token2Vault?.balance!
      self.token1Identifier = poolRef.token1Vault.getType().identifier
      self.token2Identifier = poolRef.token2Vault.getType().identifier
    }
  }

  // The following should all be part of an individual Pool resource.

  pub resource Pool {
    pub let ID: UInt64

    // Frozen flag controlled by Admin
    pub var isFrozen: Bool
              
    // Fee charged when performing token swap
    pub var feePercentage: UFix64

    // Token Vaults
    access(contract) var token1Vault: @FungibleToken.Vault?
    access(contract) var token2Vault: @FungibleToken.Vault?

    pub fun getFeePercentage(): UFix64 {
      return self.feePercentage
    }

    pub fun updateFeePercentage(feePercentage: UFix64) {
      self.feePercentage = feePercentage

      emit FeeUpdated(feePercentage: feePercentage)
    }

    // Check current pool amounts
    pub fun getPoolMeta(): PoolMeta {
      pre {
        self.token1Vault != nil && self.token2Vault != nil : "Pools are not initalized!"
      }
      // return PoolMeta(token1Amount: self.token1Vault?.balance!, token2Amount: self.token2Vault?.balance!)
      return PoolMeta(poolRef: &self as &Pool)
    }

    // Get quote for Token1 (given) -> Token2
    pub fun quoteSwapExactToken1ForToken2(amount: UFix64): UFix64 {
      let PoolMeta = self.getPoolMeta()

      // token1Amount * token2Amount = token1Amount' * token2Amount' = (token1Amount + amount) * (token2Amount - quote)
      let quote = PoolMeta.token2Amount * amount / (PoolMeta.token1Amount + amount);

      return quote
    }

    // Get quote for Token1 -> Token2 (given)
    pub fun quoteSwapToken1ForExactToken2(amount: UFix64): UFix64 {
      let PoolMeta = self.getPoolMeta()

      assert(PoolMeta.token2Amount > amount, message: "Not enough Token2 in the pool")

      // token1Amount * token2Amount = token1Amount' * token2Amount' = (token1Amount + quote) * (token2Amount - amount)
      let quote = PoolMeta.token1Amount * amount / (PoolMeta.token2Amount - amount);

      return quote
    }

    // Get quote for Token2 (given) -> Token1
    pub fun quoteSwapExactToken2ForToken1(amount: UFix64): UFix64 {
      let PoolMeta = self.getPoolMeta()

      // token1Amount * token2Amount = token1Amount' * token2Amount' = (token2Amount + amount) * (token1Amount - quote)
      let quote = PoolMeta.token1Amount * amount / (PoolMeta.token2Amount + amount);

      return quote
    }

    // Get quote for Token2 -> Token1 (given)
    pub fun quoteSwapToken2ForExactToken1(amount: UFix64): UFix64 {
      let PoolMeta = self.getPoolMeta()

      assert(PoolMeta.token1Amount > amount, message: "Not enough Token1 in the pool")

      // token1Amount * token2Amount = token1Amount' * token2Amount' = (token2Amount + quote) * (token1Amount - amount)
      let quote = PoolMeta.token2Amount * amount / (PoolMeta.token1Amount - amount);

      return quote
    }

    // Swaps Token1 -> Token2
    pub fun swapToken1ForToken2(from: @FungibleToken.Vault): @FungibleToken.Vault {
      pre {
        !self.isFrozen: "EmuSwap is frozen"
        from.balance > UFix64(0): "Empty token vault"
        self.token1Vault != nil : "This should save me doing the if else destroy panic pattern below"
      }

      // Calculate amount from pricing curve
      // A fee portion is taken from the final amount
      let token1Amount = from.balance * (1.0 - self.feePercentage)
      let token2Amount = self.quoteSwapExactToken1ForToken2(amount: token1Amount)

      assert(token2Amount > UFix64(0), message: "Exchanged amount too small")

      if self.token1Vault != nil {
        self.token1Vault?.deposit!(from: <- from)
      } else {
        destroy from
        panic("")
      }

      emit Trade(token1Amount: token1Amount, token2Amount: token2Amount, side: 1)

      let token2 <- self.token2Vault?.withdraw(amount: token2Amount)
        ?? panic("sheit2")

      return <- token2
    }

    // Swap Token2 -> Token1
    pub fun swapToken2ForToken1(from: @FungibleToken.Vault): @FungibleToken.Vault {
      pre {
        !self.isFrozen: "EmuSwap is frozen"
        from.balance > UFix64(0): "Empty token vault"
        self.token2Vault != nil: "This should save the if else destory panic dance below"
      }

      // Calculate amount from pricing curve
      // A fee portion is taken from the final amount
      let token2Amount = from.balance * (1.0 - self.feePercentage)
      let token1Amount = self.quoteSwapExactToken2ForToken1(amount: token2Amount)

      assert(token1Amount > UFix64(0), message: "Exchanged amount too small")

      // 
      if self.token2Vault != nil {
        self.token2Vault?.deposit!(from: <- from)
      } else {
        destroy from
        panic("oopsie!")
      }

      emit Trade(token1Amount: token1Amount, token2Amount: token2Amount, side: 2)

      let token1 <- self.token1Vault?.withdraw(amount: token1Amount) 
        ?? panic("sheit")
      
      return <- token1
    }

    // Used to add liquidity without minting new liquidity token
    pub fun donateLiquidity(from: @EmuSwap.TokenBundle) {
      let token1Vault <- from.withdrawToken1()
      let token2Vault <- from.withdrawToken2()

      // Check if vault is initalized otherwise initalize the liquidity
      if self.token1Vault != nil {
        self.token1Vault?.deposit!(from: <- token1Vault)
      } else {
        self.token1Vault <-! token1Vault
      }

      if self.token2Vault != nil {
        self.token2Vault?.deposit!(from: <- token2Vault)
      } else {
        self.token2Vault <-! token2Vault
      }

      destroy from
    }

    pub fun addLiquidity(from: @EmuSwap.TokenBundle): @EmuSwap.TokenVault {
      pre {
        EmuSwap.totalSupplyByID[self.ID]! > UFix64(0): "Pair must be initialized by admin first"
      }

      let token1Vault <- from.withdrawToken1()
      let token2Vault <- from.withdrawToken2()

      assert(token1Vault.balance > UFix64(0), message: "Empty token1 vault")
      assert(token2Vault.balance > UFix64(0), message: "Empty token2 vault")

      // shift decimal 4 places to avoid truncation error
      let token1Percentage: UFix64 = (token1Vault.balance * 10000.0) / self.token1Vault?.balance!
      let token2Percentage: UFix64 = (token2Vault.balance * 10000.0) / self.token2Vault?.balance!

      // final liquidity token minted is the smaller between token1Liquidity and token2Liquidity
      // to maximize profit, user should add liquidity propotional to current liquidity
      let liquidityPercentage = token1Percentage < token2Percentage ? token1Percentage : token2Percentage;

      assert(liquidityPercentage > UFix64(0), message: "Liquidity too small")

      if token1Vault != nil {
        self.token1Vault?.deposit!(from: <- token1Vault)
      } else {
        destroy token1Vault
        panic("Don't destroy the vault but keep the checkher happy!")
      }

      if token2Vault != nil {
        self.token2Vault?.deposit!(from: <- token2Vault)
      } else {
        destroy token2Vault
        panic("Don't destroy the vault but keep the checker happy")
      }

      let liquidityTokenVault <- EmuSwap.mintTokens(tokenID: 0, amount: (EmuSwap.totalSupplyByID[0]! * liquidityPercentage) / 10000.0)

      destroy from
      return <- liquidityTokenVault
    }

    pub fun removeLiquidity(from: @EmuSwap.TokenVault): @EmuSwap.TokenBundle {
      pre {
        from.balance > UFix64(0): "Empty liquidity token vault"
        from.balance < EmuSwap.totalSupplyByID[self.ID]!: "Cannot remove all liquidity"
      }

      // shift decimal 4 places to avoid truncation error
      let liquidityPercentage = (from.balance * 10000.0) / EmuSwap.totalSupplyByID[0]!

      assert(liquidityPercentage > UFix64(0), message: "Liquidity too small")

      // Burn liquidity tokens and withdraw
      EmuSwap.burnTokens(from: <- from)
      

      let token1Vault <- self.token1Vault?.withdraw(amount: (self.token1Vault?.balance! * liquidityPercentage) / 10000.0)!
      let token2Vault <- self.token2Vault?.withdraw(amount: (self.token2Vault?.balance! * liquidityPercentage) / 10000.0)!

      let tokenBundle <- EmuSwap.createTokenBundle(fromToken1: <- token1Vault, fromToken2: <- token2Vault)
      return <- tokenBundle
    }

    access(contract) fun togglePoolFreeze() {
      self.isFrozen = !self.isFrozen
    }

    init() {
      self.isFrozen = true // frozen until admin unfreezes
      self.feePercentage = 0.003 // 0.3%

      self.token1Vault <- nil
      self.token2Vault <- nil

      self.ID = EmuSwap.nextPoolID
      
      let tokenName = self.token1Vault.getType().identifier
        .concat(":")
        .concat(self.token2Vault.getType().identifier)
      
      let tokenSymbol = ""

      // j00lz - could create a linked list of tokens to the pool id... ie. {"FUSD:FLOW": 0}, {FLOW:FUSD: 0} 
      // so can easily lookup the when exchanging
      // and create a router that performs multiple swaps?

      // Emit an event that shows that the contract was initialized
      emit TokensInitialized(tokenID: self.ID)
      ///emit TokensInitialized(tokenID: self.ID, tokenName: tokenName, tokenSymbol: tokenSymbol, initialSupply: EmuSwap.totalSupplyByID[self.ID]!)
    }

    destroy() {
      // j00lz add safety mechanism
      destroy self.token1Vault
      destroy self.token2Vault
    }
  }

  pub fun borrowPool(id: UInt64): &Pool? {
   
    if EmuSwap.poolsByID[id] != nil {
      return &EmuSwap.poolsByID[id] as &Pool
    }
    else {
      return nil
    }
  }

  pub fun getPoolIDs(): [UInt64] {
    return EmuSwap.poolsByID.keys
  }

  // https://docs.onflow.org/cadence/language/accounts/#paths
  // StoragePath function not yet merged in Cadence.....
  pub fun getLPTokensStoragePath(tokenID: UInt64): String { // StoragePath {
    pre {
      EmuSwap.poolsByID[tokenID] != nil
    }
    return self.LPTokensStoragePath.toString().concat(tokenID.toString())
    //return StoragePath(identifier: self.LPTokensStoragePath.toString().concat(tokenID.toString()))
  }


  pub resource Collection: FungibleTokens.CollectionPublic {
    pub var ownedVaults: @{UInt64: FungibleTokens.TokenVault}

    pub fun deposit(token: @FungibleTokens.TokenVault) {
      if self.ownedVaults[token.tokenID] == nil {
        let nullResource <- 
          self.ownedVaults.insert(key: token.tokenID, <- token)
        destroy nullResource
      } else {
        self.ownedVaults[token.tokenID]?.deposit!(from: <- token)
      }
    }

    pub fun getIDs(): [UInt64] {
      return self.ownedVaults.keys
    }

    pub fun borrowVault(id: UInt64): &FungibleTokens.TokenVault {
      return &self.ownedVaults[id] as! &FungibleTokens.TokenVault
    }

      init() {
        self.ownedVaults <- {}
      }

      destroy () {
        destroy self.ownedVaults
      }
  }

  pub fun createEmptyCollection(): @FungibleTokens.Collection {
    return <-create Collection() 
  }

  
  init() {
    self.totalSupplyByID = {}
    self.poolsByID <- {}
    self.nextPoolID = 0
    
    self.LPTokensStoragePath = /storage/EmuSwapVaults
    self.LPTokensPublicBalancePath = /public/EmuSwapBalance
    self.LPTokensPublicReceiverPath = /public/EmuSwapReceiver

    self.AdminStoragePath = /storage/EmuSwapAdmin

    let admin <- create Admin()
    self.account.save(<-admin, to: EmuSwap.AdminStoragePath)

    emit ContractInitialized()
  }
}
