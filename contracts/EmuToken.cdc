import FungibleToken from "./dependencies/FungibleToken.cdc"

pub contract EmuToken: FungibleToken {

    // Total supply of Flow tokens in existence
    pub var totalSupply: UFix64

    // Storage Paths
    pub let EmuTokenStoragePath: StoragePath
    pub let EmuTokenBalancePublicPath: PublicPath
    pub let EmuTokenReceiverPublicPath: PublicPath 


    // Event that is emitted when the contract is created
    pub event TokensInitialized(initialSupply: UFix64)

    // Event that is emitted when tokens are withdrawn from a Vault
    pub event TokensWithdrawn(amount: UFix64, from: Address?)

    // Event that is emitted when tokens are deposited to a Vault
    pub event TokensDeposited(amount: UFix64, to: Address?)

    // Event that is emitted when new tokens are minted
    pub event TokensMinted(amount: UFix64)

    // Event that is emitted when tokens are destroyed
    pub event TokensBurned(amount: UFix64)

    // Event that is emitted when a new minter resource is created
    pub event MinterCreated(allowedAmount: UFix64)

    // Event that is emitted when a new burner resource is created
    pub event BurnerCreated()

    // Vault
    //
    // Each user stores an instance of only the Vault in their storage
    // The functions in the Vault and governed by the pre and post conditions
    // in FungibleToken when they are called.
    // The checks happen at runtime whenever a function is called.
    //
    // Resources can only be created in the context of the contract that they
    // are defined in, so there is no way for a malicious user to create Vaults
    // out of thin air. A special Minter resource needs to be defined to mint
    // new tokens.
    //
    pub resource Vault: FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance {

        // holds the balance of a users tokens
        pub var balance: UFix64

        // initialize the balance at resource creation time
        init(balance: UFix64) {
            self.balance = balance
        }

        // withdraw
        //
        // Function that takes an integer amount as an argument
        // and withdraws that amount from the Vault.
        // It creates a new temporary Vault that is used to hold
        // the money that is being transferred. It returns the newly
        // created Vault to the context that called so it can be deposited
        // elsewhere.
        //
        pub fun withdraw(amount: UFix64): @FungibleToken.Vault {
            self.balance = self.balance - amount
            emit TokensWithdrawn(amount: amount, from: self.owner?.address)
            return <-create Vault(balance: amount)
        }

        // deposit
        //
        // Function that takes a Vault object as an argument and adds
        // its balance to the balance of the owners Vault.
        // It is allowed to destroy the sent Vault because the Vault
        // was a temporary holder of the tokens. The Vault's balance has
        // been consumed and therefore can be destroyed.
        pub fun deposit(from: @FungibleToken.Vault) {
            let vault <- from as! @EmuToken.Vault
            self.balance = self.balance + vault.balance
            emit TokensDeposited(amount: vault.balance, to: self.owner?.address)
            vault.balance = 0.0
            destroy vault
        }

        destroy() {
            EmuToken.totalSupply = EmuToken.totalSupply - self.balance
        }
    }

    // createEmptyVault
    //
    // Function that creates a new Vault with a balance of zero
    // and returns it to the calling context. A user must call this function
    // and store the returned Vault in their storage in order to allow their
    // account to be able to receive deposits of this token type.
    //
    pub fun createEmptyVault(): @FungibleToken.Vault {
        return <-create Vault(balance: 0.0)
    }

    // Account restricted functions 
    //
    // To distribute funds according to appropriate parties white paper
    // can store these internally in the contract instead of saving to storage

    access(account) fun withdrawLiquidityTokens(): @FungibleToken.Vault {
        let vaultRef = self.account.borrow<&EmuToken.Vault>(from: /storage/liquidityMiningTokens)!
        return <- vaultRef.withdraw(amount: vaultRef.balance)
    }

    access(account) fun withdrawAirdropTokens(): @FungibleToken.Vault {
        let vaultRef = self.account.borrow<&EmuToken.Vault>(from: /storage/airdropTokens)!
        return <- vaultRef.withdraw(amount: vaultRef.balance)
    }

    access(account) fun withdrawStakersTokens(): @FungibleToken.Vault {
        let vaultRef = self.account.borrow<&EmuToken.Vault>(from: /storage/stakersTokens)!
        return <- vaultRef.withdraw(amount: vaultRef.balance)
    }

    access(account) fun withdrawTeamTokens(): @FungibleToken.Vault {
        let vaultRef = self.account.borrow<&EmuToken.Vault>(from: /storage/teamTokens)!
        return <- vaultRef.withdraw(amount: vaultRef.balance)
    }

    init() {
        self.totalSupply = 100_000_000.0

        // init storage paths
        self.EmuTokenStoragePath = /storage/emuTokenVault
        self.EmuTokenBalancePublicPath = /public/emuTokenBalance
        self.EmuTokenReceiverPublicPath = /public/emuTokenReceiver

        // Create the Vault with the total supply of tokens and save it in storage
        //
        let vault <- create Vault(balance: self.totalSupply)

        // save and use access(account) functions to withdraw to the other contracts for distributing/claiming....
        let liquidityMiningTokens <- vault.withdraw(amount: 0.40 * self.totalSupply)  // time release contract
        self.account.save(<-liquidityMiningTokens, to: /storage/liquidityMiningTokens)

        let airdropTokens <- vault.withdraw(amount: 0.02 * self.totalSupply)  // access gated contract (nft holders)
        self.account.save(<- airdropTokens, to: /storage/airdropTokens)

        let stakersTokens <- vault.withdraw(amount: 0.01 * self.totalSupply)  // access gated contract (Flow stakers *this should be small accounts only say less than 100k staked.. so Dapper VCs and Whales don't get our tokens :p )) 
        self.account.save(<- stakersTokens, to: /storage/stakersTokens)
        
        let teamTokens <- vault.withdraw(amount: 0.20 * self.totalSupply)  // time release contract
        self.account.save(<- teamTokens, to: /storage/teamTokens)
        
        // partnership Tokens are saved to the main tokenVault as the DAO Tokens.
        /*
            let liquidityMining <- vault.withdraw(amount: 0.40 * self.totalSupply)  // time release contract
            let partnerships    <- vault.withdraw(amount: 0.37 * self.totalSupply)  // multisig account (DAO Treasury Tokens)
            let airdrop         <- vault.withdraw(amount: 0.02 * self.totalSupply)  // access gated contract (NFT holders)
            let stakers         <- vault.withdraw(amount: 0.01 * self.totalSupply)  // access gated contract (Flow stakers *this should be small accounts only say less than 100k staked.. so Dapper VCs and Whales don't get our tokens :p )) 
            let team            <- vault.withdraw(amount: 0.20 * self.totalSupply)  // time release contract
         */
        
        self.account.save(<-vault, to: EmuToken.EmuTokenStoragePath)

        // Create a public capability to the stored Vault that only exposes
        // the `deposit` method through the `Receiver` interface
        //
        self.account.link<&EmuToken.Vault{FungibleToken.Receiver}>(
            EmuToken.EmuTokenReceiverPublicPath,
            target: EmuToken.EmuTokenStoragePath
        )

        // Create a public capability to the stored Vault that only exposes
        // the `balance` field through the `Balance` interface
        //
        self.account.link<&EmuToken.Vault{FungibleToken.Balance}>(
            EmuToken.EmuTokenBalancePublicPath,
            target: EmuToken.EmuTokenStoragePath
        )

        // Emit an event that shows that the contract was initialized
        emit TokensInitialized(initialSupply: self.totalSupply)
    }
}