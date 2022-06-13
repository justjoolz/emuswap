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
import MetadataViews from "../dependencies/MetadataViews.cdc"

pub contract EmuSwap: FungibleTokens {
  
    // Pools kept here and only accessible via the contract (could make account to allow for future ideas?)
    access(contract) var poolsByID: @{UInt64: Pool}

    // Map of Token Identifier (A.Vault)
    access(contract) var poolsMap: {String: {String: UInt64}}
  
    // Total supply of liquidity tokens in existence
    access(contract) var totalSupplyByID: {UInt64: UFix64}

    // DAO Fees in every token type supported
    access(contract) var feesByIdentifier: @{String: FungibleToken.Vault}

    //  unique ID for each pool
    pub var nextPoolID: UInt64
    access(contract) var LPFeePercentage: UFix64
    access(contract) var DAOFeePercentage: UFix64

    // Defines token vault storage path
    pub let LPTokensStoragePath: StoragePath

    // Defines token vault public balance path
    pub let LPTokensPublicBalancePath: PublicPath

    // Defines token vault public receiver path
    pub let LPTokensPublicReceiverPath: PublicPath

    pub let AdminStoragePath: StoragePath

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Events 
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
    pub event LPFeeUpdated(poolID: UInt64, feePercentage: UFix64)
    pub event DAOFeeUpdated(poolID: UInt64, feePercentage: UFix64)

    // j00lz can make this event more specific from: and to: with amounts and Type.identifier or maybe poolID
    pub event Trade(token1Amount: UFix64, token2Amount: UFix64, side: UInt8)
    pub event Swap(token1Amount: UFix64, token2Amount: UFix64, poolID: UInt64, direction: UInt8)
    
    // j00lz add Pool creation details (how is this different from new LP token creation?)
    pub event NewSwapPoolCreated()
    
    pub event FeesDeposited(tokenIdentifier: String, amount: UFix64)

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Structures
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // PoolMeta
    //
    // Basic metadata about a pool
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
            // poolRef.DAOFeePercentage
            // poolRef.LPFeePercentage
        }
    }
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Resources
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////
    // Pool Resource
    //
    // Main resource type created for each swap pool
    // Stored in a field the contract indexed by ID   
    //
    pub resource Pool: MetadataViews.Resolver {
        pub let ID: UInt64

        // Frozen flag controlled by Admin
        access(contract) var isFrozen: Bool

        // Token Vaults
        access(contract) var token1Vault: @FungibleToken.Vault?
        access(contract) var token2Vault: @FungibleToken.Vault?

        access(contract) var DAOFeePercentage: UFix64
        access(contract) var LPFeePercentage: UFix64

        // Pool Initalization
        //
        init(DAOFeePercentage: UFix64, LPFeePercentage: UFix64) {
            self.isFrozen = true // frozen until admin unfreezes
            self.token1Vault <- nil
            self.token2Vault <- nil

            self.ID = EmuSwap.nextPoolID
            self.DAOFeePercentage = DAOFeePercentage
            self.LPFeePercentage = LPFeePercentage
            
            // Emit an event that shows that the contract was initialized
            emit TokensInitialized(tokenID: self.ID)
            ///emit TokensInitialized(tokenID: self.ID, tokenName: tokenName, tokenSymbol: tokenSymbol, initialSupply: EmuSwap.totalSupplyByID[self.ID]!)
        }

        destroy() {
            // j00lz add safety mechanism
            destroy self.token1Vault
            destroy self.token2Vault
        }

        // Get Pool Meta
        //
        // Returns metadata information about the pool (j00lz 2 do implement new MetaDataViews standard )
        pub fun getPoolMeta(): PoolMeta {
            pre { 
                self.token1Vault != nil && self.token2Vault != nil : "Pools are not initalized!"
            }
            return PoolMeta(poolRef: &self as &Pool)
        }

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Function for Quotes
        //
        // Get quote for Token1 (given) -> Token2
        pub fun quoteSwapExactToken1ForToken2(amount: UFix64): UFix64 {
            let poolMeta = self.getPoolMeta()

            // token1Amount * token2Amount = token1Amount' * token2Amount' = (token1Amount + amount) * (token2Amount - quote)
            let quote = poolMeta.token2Amount * amount / (poolMeta.token1Amount + amount);

            return quote
        }

        // Get quote for Token1 -> Token2 (given)
        pub fun quoteSwapToken1ForExactToken2(amount: UFix64): UFix64 {
            let poolMeta = self.getPoolMeta()

            assert(poolMeta.token2Amount > amount, message: "Not enough Token2 in the pool")

            // token1Amount * token2Amount = token1Amount' * token2Amount' = (token1Amount + quote) * (token2Amount - amount)
            let quote = poolMeta.token1Amount * amount / (poolMeta.token2Amount - amount);

            return quote
        }

        // Get quote for Token2 (given) -> Token1
        pub fun quoteSwapExactToken2ForToken1(amount: UFix64): UFix64 {
            let poolMeta = self.getPoolMeta()

            // token1Amount * token2Amount = token1Amount' * token2Amount' = (token2Amount + amount) * (token1Amount - quote)
            let quote = poolMeta.token1Amount * amount / (poolMeta.token2Amount + amount);

            return quote
        }

        // Get quote for Token2 -> Token1 (given)
        pub fun quoteSwapToken2ForExactToken1(amount: UFix64): UFix64 {
            let poolMeta = self.getPoolMeta()

            assert(poolMeta.token1Amount > amount, message: "Not enough Token1 in the pool")

            // token1Amount * token2Amount = token1Amount' * token2Amount' = (token2Amount + quote) * (token1Amount - amount)
            let quote = poolMeta.token2Amount * amount / (poolMeta.token1Amount - amount);

            return quote
        }

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // Swap Functions
        //
        // Swaps Token1 -> Token2
        //
        pub fun swapToken1ForToken2(from: @FungibleToken.Vault): @FungibleToken.Vault {
            pre {
                !self.isFrozen: "EmuSwap is frozen"
                from.balance > 0.0: "Empty token vault"
                self.token1Vault != nil : "This should save me doing the if else destroy panic pattern below"
            }
            let originalBalance = from.balance

            // Withdraw DAO fee from input tokens.
            let fees <- from.withdraw(amount: from.balance * self.DAOFeePercentage)
            EmuSwap.storeFees(fees: <-fees)

            // Calculate amount from pricing curve
            // A fee portion is taken from the input
            let token1Amount = originalBalance * (1.0 - self.LPFeePercentage - self.DAOFeePercentage)
            let token2Amount = self.quoteSwapExactToken1ForToken2(amount: token1Amount)

            assert(token2Amount > 0.0, message: "Exchanged amount too small")

            self.token1Vault?.deposit!(from: <- from)

            emit Trade(token1Amount: token1Amount, token2Amount: token2Amount, side: 1)

            return <- self.token2Vault?.withdraw(amount: token2Amount)!
        }

        // Swap Token2 -> Token1
        //
        pub fun swapToken2ForToken1(from: @FungibleToken.Vault): @FungibleToken.Vault {
            pre {
                !self.isFrozen: "EmuSwap is frozen"
                from.balance > 0.0: "Empty token vault"
                self.token2Vault != nil: "This should save the if else destory panic dance below"
            }
            let originalBalance = from.balance

            // Withdraw DAO fee from input tokens.
            let fees <- from.withdraw(amount: from.balance * self.DAOFeePercentage)
            EmuSwap.storeFees(fees: <-fees)

            // Calculate amount from pricing curve
            // A fee portion is taken from the final amount
            let token2Amount = originalBalance * (1.0 - self.LPFeePercentage - self.DAOFeePercentage)
            let token1Amount = self.quoteSwapExactToken2ForToken1(amount: token2Amount)

            assert(token1Amount > 0.0, message: "Exchanged amount too small")

            self.token2Vault?.deposit!(from: <- from)
            
            emit Trade(token1Amount: token1Amount, token2Amount: token2Amount, side: 2)

            return <- self.token1Vault?.withdraw(amount: token1Amount)!
        }

        // Donate Liquidity
        //
        // Used to add liquidity without minting new liquidity token
        //
        pub fun donateLiquidity(from: @EmuSwap.TokenBundle) {
            let token1Vault <- from.withdrawToken1()
            let token2Vault <- from.withdrawToken2()
            destroy from

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
        }

        // Add Liquidity
        //
        // Public function to add liquidity to the pool
        //
        pub fun addLiquidity(from: @EmuSwap.TokenBundle): @EmuSwap.TokenVault {
            pre {
                EmuSwap.totalSupplyByID[self.ID]! > 0.0: "Pair must be initialized by admin first"
            }

            let token1Vault <- from.withdrawToken1()
            let token2Vault <- from.withdrawToken2()
            destroy from

            assert(token1Vault.balance > 0.0, message: "Empty token1 vault")
            assert(token2Vault.balance > 0.0, message: "Empty token2 vault")

            // shift decimal 4 places to avoid truncation error
            let token1Percentage: UFix64 = (token1Vault.balance * 10000.0) / self.token1Vault?.balance!
            let token2Percentage: UFix64 = (token2Vault.balance * 10000.0) / self.token2Vault?.balance!

            // final liquidity token minted is the smaller between token1Liquidity and token2Liquidity
            // to maximize profit, user should add liquidity propotional to current liquidity
            let liquidityPercentage = token1Percentage < token2Percentage ? token1Percentage : token2Percentage;

            assert(liquidityPercentage > 0.0, message: "Insufficient Liquidity provided")

            // deposit liquidity
            self.token1Vault?.deposit!(from: <- token1Vault)
            self.token2Vault?.deposit!(from: <- token2Vault)

            return <- EmuSwap.mintTokens(tokenID: self.ID, amount: (EmuSwap.totalSupplyByID[0]! * liquidityPercentage) / 10000.0)
        }

        // Remove Liquidity
        //
        // Function to withdraw users liquidity from the pool
        // 
        pub fun removeLiquidity(from: @EmuSwap.TokenVault): @EmuSwap.TokenBundle {
            pre {
                from.balance > 0.0: "Empty LP token vault"
                from.balance < EmuSwap.totalSupplyByID[self.ID]!: "Cannot remove all liquidity"
            }

            // shift decimal 4 places to avoid truncation error
            let liquidityPercentage = (from.balance * 10000.0) / EmuSwap.totalSupplyByID[0]!

            assert(liquidityPercentage > 0.0, message: "Insufficient Liquidity")

            // Burn liquidity tokens and withdraw tokens to bundle
            EmuSwap.burnTokens(from: <- from)
            let token1Vault <- self.token1Vault?.withdraw(amount: (self.token1Vault?.balance! * liquidityPercentage) / 10000.0)!
            let token2Vault <- self.token2Vault?.withdraw(amount: (self.token2Vault?.balance! * liquidityPercentage) / 10000.0)!

            return <- EmuSwap.createTokenBundle(fromToken1: <- token1Vault, fromToken2: <- token2Vault)
        }

        // Toggle Pool Freeze 
        //
        access(contract) fun togglePoolFreeze() {
            self.isFrozen = !self.isFrozen
        }

        access(contract) fun setDAOFeePercentage(_ feePercentage: UFix64) {
            self.DAOFeePercentage = feePercentage
        }
        
        access(contract) fun setLPFeePercentage(_ feePercentage: UFix64) {
            self.LPFeePercentage = feePercentage
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>()
            ]
        }
        pub fun resolveView(_ view: Type): AnyStruct? {
           let metadata = self.getPoolMeta()
           switch view {
               case Type<MetadataViews.Display>():
                return MetadataViews.Display(
                    name: metadata.token1Identifier.concat(":").concat(metadata.token2Identifier),
                    description: "Description of this pool",
                    thumbnail: MetadataViews.HTTPFile(
                        url: "//Thumbnail.jpg"
                    )
                )
           }
           return nil
        }

    }

    // TokenVault
    //
    // The LP Tokens that are issued are stored in TokenVaults
    pub resource TokenVault: FungibleTokens.Provider, FungibleTokens.Receiver, FungibleTokens.Balance, MetadataViews.Resolver {

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

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            let meta = EmuSwap.borrowPool(id: self.tokenID)!.getPoolMeta()
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: meta.token1Identifier.concat(":").concat(meta.token2Identifier),
                        description: "Description of this LPToken",
                        thumbnail: MetadataViews.HTTPFile(
                            url: "//LPTokenThumbnail.jpg"
                        )
                    )
           }
           return nil
        }

        destroy() {
            EmuSwap.totalSupplyByID[self.tokenID] = EmuSwap.totalSupplyByID[self.tokenID]! - self.balance
        }
    }


    // Token Bundle 
    //
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

        // returns identifiers with ".Vault" from "A.f8d6e0586b0a20c7.FUSD.Vault"
        pub fun getIdentifiers(): [String] {
            let ids = [self.token1.getType().identifier, self.token2.getType().identifier]
            ids[0] = ids[0].slice(from: 0, upTo: ids[0].length - 6)
            ids[1] = ids[1].slice(from: 0, upTo: ids[1].length - 6)
            return ids
        }

        destroy() {
            destroy self.token1
            destroy self.token2
        }
    }

    // Collection
    //
    // Stored in users storage
    // and contains their LP Token Vaults
    //
    pub resource Collection: FungibleTokens.CollectionPublic, MetadataViews.ResolverCollection {
        pub var ownedVaults: @{UInt64: FungibleTokens.TokenVault}

        // Accepts any FungibleTokens and either 
        // deposits them in appropriate ownedVault 
        // or deposits whole vault if they've not been received before
        //
        pub fun deposit(token: @FungibleTokens.TokenVault) {
            if self.ownedVaults[token.tokenID] != nil {
                self.ownedVaults[token.tokenID]?.deposit!(from: <- token)
            } else {
                self.ownedVaults[token.tokenID] <-! token
            }
        }

        pub fun borrowViewResolver(id: UInt64): &{MetadataViews.Resolver} {
            let vault = (&self.ownedVaults[id] as auth &FungibleTokens.TokenVault?)
            let emuSwapVault = vault as! &EmuSwap.TokenVault
            return emuSwapVault as &{MetadataViews.Resolver} 
        }


        pub fun getIDs(): [UInt64] {
            return self.ownedVaults.keys
        }

        pub fun borrowVault(id: UInt64): &FungibleTokens.TokenVault {
            return (&self.ownedVaults[id] as! &FungibleTokens.TokenVault?)!
        }

        init() {
            self.ownedVaults <- {}
        }

        destroy () {
            destroy self.ownedVaults
        }
    }

    // Admin resource
    //
    // Stored in account contract is deployed to on initalization
    // Only the admin resource can create new pools, update fees and freeze/unfreeze pools
    //
    pub resource Admin {

        pub fun createNewLiquidityPool(from: @EmuSwap.TokenBundle): @EmuSwap.TokenVault {
            let token1 = from.getIdentifiers()[0]
            let token2 = from.getIdentifiers()[1]

            assert(token1 != token2, message: "Cannot create pool with identical tokens!")
            assert(EmuSwap.getPoolIDFromIdentifiers(token1: token1, token2: token2) == nil, message: "Pool already exists")
            
            // create new pool
            let newPool <- create Pool(DAOFeePercentage: EmuSwap.DAOFeePercentage, LPFeePercentage: EmuSwap.LPFeePercentage)
            
            // drop liquidity in
            newPool.donateLiquidity(from: <- from)

            // Add new Pool to dictionary
            EmuSwap.poolsByID[EmuSwap.nextPoolID] <-! newPool

            // Update poolMap
            if EmuSwap.poolsMap[token1] == nil {
                EmuSwap.poolsMap[token1] = {}
            }
            if EmuSwap.poolsMap[token2] == nil {
                EmuSwap.poolsMap[token2] = {}
            }
            EmuSwap.poolsMap[token1]!.insert(key: token2, EmuSwap.nextPoolID)
            EmuSwap.poolsMap[token2]!.insert(key: token1, EmuSwap.nextPoolID)

            // Create initial tokens
            let lpTokens <- EmuSwap.mintTokens(tokenID: EmuSwap.nextPoolID, amount: 1.0)

            // increment ready for next new pool
            EmuSwap.nextPoolID = EmuSwap.nextPoolID + 1
            
            // j00lz 2do add details to event
            emit NewSwapPoolCreated()

            return <- lpTokens
        }

        pub fun updateLPFeePercentage(id: UInt64, feePercentage: UFix64) {
            (&EmuSwap.poolsByID[id] as &Pool?)!.setLPFeePercentage(feePercentage)
            emit LPFeeUpdated(poolID: id, feePercentage: feePercentage)
        }
        
        pub fun updateDAOFeePercentage(id: UInt64, feePercentage: UFix64) {
            (&EmuSwap.poolsByID[id] as &Pool?)!.setDAOFeePercentage(feePercentage)
            emit DAOFeeUpdated(poolID: id, feePercentage: feePercentage)
        }

        pub fun togglePoolFreeze(id: UInt64) {
            (&EmuSwap.poolsByID[id] as &Pool?)!.togglePoolFreeze()
        }
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Public Functions
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    pub fun createTokenBundle(fromToken1: @FungibleToken.Vault, fromToken2: @FungibleToken.Vault): @EmuSwap.TokenBundle {
        return <- create TokenBundle(fromToken1: <- fromToken1, fromToken2: <- fromToken2)
    }

    pub fun createEmptyTokenVault(tokenID: UInt64): @EmuSwap.TokenVault {
        return <-create TokenVault(tokenID: tokenID, balance: 0.0)
    }

    pub fun createEmptyCollection(): @FungibleTokens.Collection {
        return <-create Collection() 
    }

    // borrowPool
    //
    // returns reference to the requested pool if it exists or nil for caller to handle
    //
    pub fun borrowPool(id: UInt64): &Pool? {
        return &EmuSwap.poolsByID[id] as &Pool?
    }

    pub fun getPoolIDs(): [UInt64] {
        return EmuSwap.poolsByID.keys
    }

    pub fun getSwapsAvailableForToken(identifier: String): {String: UInt64}? {
        return self.poolsMap[identifier]
    }

    pub fun getAllRoutes(): {String: {String: UInt64}} {
        return self.poolsMap
    }

    pub fun getPoolIDFromIdentifiers(token1: String, token2: String): UInt64? {
        let token1ToToken2Exists = EmuSwap.poolsMap.containsKey(token1) && EmuSwap.poolsMap[token1]!.containsKey(token2) 
        let token2ToToken1Exists = EmuSwap.poolsMap.containsKey(token2) && EmuSwap.poolsMap[token2]!.containsKey(token1) 

        if token1ToToken2Exists && token2ToToken1Exists {
            return self.poolsMap[token1]![token2]!
        } else {
            return nil
        }
    }

    // j00lz todo add these to metadata format... 
    pub fun getLPFeePercentage(): UFix64 {
        return self.LPFeePercentage
    }
        
    pub fun getDAOFeePercentage(): UFix64 {
        return self.DAOFeePercentage
    }

    // public function to see all fees collected by protocol
    pub fun readFeesCollected(): {String: UFix64} {
        let feesCollectedByIdentifier: {String: UFix64} = {}

        for key in EmuSwap.feesByIdentifier.keys {
            let value = EmuSwap.feesByIdentifier[key]?.balance!
            feesCollectedByIdentifier.insert(key: key, value)
        }
        return feesCollectedByIdentifier
    }


    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Private Functions
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // mintTokens
    //
    // Function that mints new tokens, adds them to the total supply,
    // and returns them to the calling context.
    //
    access(contract) fun mintTokens(tokenID: UInt64, amount: UFix64): @EmuSwap.TokenVault {
        pre {
            amount > 0.0: "Amount minted must be greater than zero"
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
        let vault <- from
        let amount = vault.balance
        let tokenID = vault.tokenID
        destroy vault
        emit TokensBurned(tokenID: tokenID, amount: amount)
    }

    access(contract) fun storeFees(fees: @FungibleToken.Vault) {
        let identifier = fees.getType().identifier
        let amount = fees.balance
        // check if fees of this token type have already been collected
        if EmuSwap.feesByIdentifier[identifier] != nil {
            EmuSwap.feesByIdentifier[identifier]?.deposit!(from: <-fees)
        } else { // first times fees of this type collected
            EmuSwap.feesByIdentifier[identifier] <-! fees
        }
        emit FeesDeposited(tokenIdentifier: identifier, amount: amount)
    }



    // Helper Functions

    pub fun getContractAddress(_ str: String): String {
        return EmuSwap.split(str)[0]
    }

    pub fun getContractName(_ str: String): String {
        return EmuSwap.split(str)[1]
    }

    pub fun getResourceName(_ str: String): String {
        return EmuSwap.split(str)[2]
    }

    // split("A.f8d6e0586b0a20c7.ExampleNFT.NFT") returns ["f8d6e0586b0a20c7", "ExampleNFT", "NFT"]
    pub fun split(_ str: String): [String] {
        let at = EmuSwap.at(str)
        var chunks: [String] = []
        var i = 1
        var bottom = 0
        var top = at[0]
        while i < at.length  {
            bottom = top
            top = at[i]
            chunks.append(str.slice(from: bottom+1, upTo: top))
            i = i + 1
        }
        chunks.append(str.slice(from: top+1, upTo: str.length))
        return chunks
    }

    pub fun at(_ input: String): [Int] {
        var i = 0
        var at: [Int] = []

        while i < input.length {
            if input[i] == "." {
                at.append(i)
            }
            i = i + 1
        }

        return at
    }
    
    // Contract Initalization
    // 
    // Sets up fees, paths and stores Admin resource to storage
    //  
    init() {
        self.totalSupplyByID = {}
        self.poolsByID <- {}
        self.poolsMap = {}
        self.nextPoolID = 0
        
        // defaults for new pools
        self.LPFeePercentage  = 0.0025 // 0.25%
        self.DAOFeePercentage = 0.0005 // 0.05%
        self.feesByIdentifier <- {}

        self.LPTokensStoragePath = /storage/EmuSwapVaults
        self.LPTokensPublicBalancePath = /public/EmuSwapBalance
        self.LPTokensPublicReceiverPath = /public/EmuSwapReceiver

        self.AdminStoragePath = /storage/EmuSwapAdmin

        destroy self.account.load<@AnyResource>(from: EmuSwap.AdminStoragePath)
        self.account.save(<- create Admin(), to: EmuSwap.AdminStoragePath)

        emit ContractInitialized()
    }
}
