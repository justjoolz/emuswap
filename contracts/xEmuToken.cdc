// xEmuToken
//
// Yield bearing token....
//
// User stakes Emu using enterPool function
// xEmu tokens are Issued to user when they deposit Emu tokens 

// User can unstake at any time by calling leavePool function
// Sending in xEmu and getting the appropriate amount of emu in return

// the depositRewards function accepts only Emu tokens and can be called by any other user or contract
//



import FungibleToken from "./dependencies/FungibleToken.cdc"
import EmuToken from "./EmuToken.cdc"
import EmuSwap from "./exchange/EmuSwap.cdc"
pub contract xEmuToken: FungibleToken {

    access(contract) var emuPool: @FungibleToken.Vault

    // Total supply of Flow tokens in existence
    pub var totalSupply: UFix64

    // xEmuVault Storage Path
    pub let xEmuTokenVaultStoragePath: StoragePath
    
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
            let vault <- from as! @xEmuToken.Vault
            self.balance = self.balance + vault.balance
            emit TokensDeposited(amount: vault.balance, to: self.owner?.address)
            vault.balance = 0.0
            destroy vault
        }

        destroy() {
            xEmuToken.totalSupply = xEmuToken.totalSupply - self.balance
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


    // Access Contract Minting and Burning functionality 
    // mintTokens
    //
    // Function that mints new tokens, adds them to the total supply,
    // and returns them to the calling context.
    //
    access(contract) fun mintTokens(amount: UFix64): @xEmuToken.Vault {
        pre {
            amount > 0.0: "Amount minted must be greater than zero"
        }
        xEmuToken.totalSupply = xEmuToken.totalSupply + amount
        emit TokensMinted(amount: amount)
        return <-create Vault(balance: amount)
    }

    // burnTokens
    //
    // Function that destroys a Vault instance, effectively burning the tokens.
    //
    // Note: the burned tokens are automatically subtracted from the
    // total supply in the Vault destructor.
    //
    access(contract) fun burnTokens(from: @FungibleToken.Vault) {
        let vault <- from as! @xEmuToken.Vault
        let amount = vault.balance
        destroy vault
        emit TokensBurned(amount: amount)
    }

    // enterPool
    //
    // Public function to stake Emu tokens in the pool. 
    // Return freshly minted xEmu
    //
    pub fun enterPool(emuTokens: @FungibleToken.Vault): @FungibleToken.Vault {
        pre {
            emuTokens.balance > 0.0 : "Insufficient tokens!"
        }
        // Gets the amount of Emu locked in the contract
        let totalEmu = self.emuPool.balance
        // Gets the amount of xEmu in existence
        let totalShares = self.totalSupply

        let xEmuTokens <- self.createEmptyVault()
        // If no xEmu exists, mint it 1:1 to the amount put in
        if totalShares == 0.0 || totalEmu == 0.0 {
            xEmuTokens.deposit(from: <- self.mintTokens(amount: emuTokens.balance))
        }
        // Calculate and mint the amount of xEmu the Emu is worth. The ratio will change overtime, as xEmu is burned/minted and Emu deposited + gained from fees / withdrawn.
        else {
            let amount = emuTokens.balance * totalShares / totalEmu
            xEmuTokens.deposit(from: <- self.mintTokens(amount: amount))
        }
        // Lock the Emu Tokens in the contract
        self.emuPool.deposit(from: <-emuTokens)
        
        return <- xEmuTokens
    }

    // leavePool
    //
    // Leave the pool. Claim back your Emu.
    // Returns the staked + gained Emu and burns xEmu
    //
    pub fun leavePool(xEmuVault: @FungibleToken.Vault): @FungibleToken.Vault {
        pre {
            self.emuPool.balance > 0.0 : "Pool is empty!"
            xEmuVault.balance > 0.0 : "Insufficient xEmu Tokens!"
        }
        // Calculates the amount of Emu the xEmu is worth
        let amount = xEmuVault.balance * self.emuPool.balance / self.totalSupply
        
        self.burnTokens(from: <- xEmuVault)
        
        return <- self.emuPool.withdraw(amount: amount)
    }

    // j00lz 2do
    // Anyone can call this at any time to withdraw the Emu tokens fees from EmuSwap Contract
    pub fun withdrawFees() {
        // EmuSwap.withdrawFeesInEmu()
    }

    //
    pub fun depositRewards(funds: @FungibleToken.Vault) {
        pre {
            funds.isInstance(Type<@EmuToken.Vault>()) : "Funds provided are not EmuTokens!"
        }
        self.emuPool.deposit(from: <-funds)
    }
    
  
    init(adminAccount: AuthAccount) {
        self.emuPool <- EmuToken.createEmptyVault() 

        self.totalSupply = 0.0

        // Create the Vault with the total supply of tokens and save it in storage
        //
        let vault <- create Vault(balance: self.totalSupply)

        self.xEmuTokenVaultStoragePath = /storage/xEmuTokenVault
        adminAccount.save(<-vault, to: self.xEmuTokenVaultStoragePath)

        // Create a public capability to the stored Vault that only exposes
        // the `deposit` method through the `Receiver` interface
        //
        adminAccount.link<&xEmuToken.Vault{FungibleToken.Receiver}>(
            /public/xEmuTokenReceiver,
            target: self.xEmuTokenVaultStoragePath
        )

        // Create a public capability to the stored Vault that only exposes
        // the `balance` field through the `Balance` interface
        //
        adminAccount.link<&xEmuToken.Vault{FungibleToken.Balance}>(
            /public/xEmuTokenBalance,
            target: self.xEmuTokenVaultStoragePath
        )

        // Emit an event that shows that the contract was initialized
        emit TokensInitialized(initialSupply: self.totalSupply)
    }
}