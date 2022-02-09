/**

## The Flow Fungible Token standard

## `FungibleTokens` contract interface

The FungibleTokens allows a single contract to issue a collection of FungibleTokens  

The interface that all Fungible tokens contracts could conform to.
If a user wants to deploy a new Vault contract, their contract would need
to implement the FungibleTokens interface.

Their contract would have to follow all the rules and naming
that the interface specifies.

## `Vault` resource

The core resource type that represents an Vault in the smart contract.

## `Collection` Resource

The resource that stores a user's Vault collection.
It includes a few functions to allow the owner to easily
move tokens in and out of the collection.

## `Provider` and `Receiver` resource interfaces

These interfaces declare functions with some pre and post conditions
that require the Collection to follow certain naming and behavior standards.

They are separate because it gives the user the ability to share a reference
to their Collection that only exposes the fields and functions in one or more
of the interfaces. It also gives users the ability to make custom resources
that implement these interfaces to do various things with the tokens.

By using resources and interfaces, users of Vault smart contracts can send
and receive tokens peer-to-peer, without having to interact with a central ledger
smart contract.

To send an Vault to another user, a user would simply withdraw the Vault
from their Collection, then call the deposit function on another user's
Collection to complete the transfer.

*/

// The main Vault contract interface. Other Vault contracts will
// import and implement this interface
//
pub contract interface FungibleTokens {

    // Map of total token supply in existence by type
    access(contract) var totalSupplyByID: {UInt64: UFix64}

    // Event that emitted when the Vault contract is initialized
    //
    pub event ContractInitialized()

    /// Provider
    ///
    /// The interface that enforces the requirements for withdrawing
    /// tokens from the implementing type.
    ///
    /// It does not enforce requirements on `balance` here,
    /// because it leaves open the possibility of creating custom providers
    /// that do not necessarily need their own balance.
    ///
    pub resource interface Provider {

        /// withdraw subtracts tokens from the owner's Vault
        /// and returns a Vault with the removed tokens.
        ///
        /// The function's access level is public, but this is not a problem
        /// because only the owner storing the resource in their account
        /// can initially call this function.
        ///
        /// The owner may grant other accounts access by creating a private
        /// capability that allows specific other users to access
        /// the provider resource through a reference.
        ///
        /// The owner may also grant all accounts access by creating a public
        /// capability that allows all users to access the provider
        /// resource through a reference.
        ///
        pub fun withdraw(amount: UFix64): @TokenVault {
            post {
                // `result` refers to the return value
                result.balance == amount:
                    "Withdrawal amount must be the same as the balance of the withdrawn Vault"
            }
        }
    }

    /// Receiver
    ///
    /// The interface that enforces the requirements for depositing
    /// tokens into the implementing type.
    ///
    /// We do not include a condition that checks the balance because
    /// we want to give users the ability to make custom receivers that
    /// can do custom things with the tokens, like split them up and
    /// send them to different places.
    ///
    pub resource interface Receiver {

        /// deposit takes a Vault and deposits it into the implementing resource type
        ///
        pub fun deposit(from: @TokenVault) 
    }

    /// Balance
    ///
    /// The interface that contains the `balance` field of the Vault
    /// and enforces that when new Vaults are created, the balance
    /// is initialized correctly.
    ///
    pub resource interface Balance {

        /// The total balance of a vault
        ///
        pub var balance: UFix64
        pub let tokenID: UInt64

        init(tokenID: UInt64, balance: UFix64) {
            post {
                self.balance == balance:
                    "Balance must be initialized to the initial balance"
                self.tokenID == tokenID:
                    "TokenID must be initalized to the supplied tokenID"
            }
        }
    }


    // Requirement that all conforming Vault smart contracts have
    // to define a resource called Vault that conforms to Provider, Receiver, Balance
    pub resource TokenVault: Provider, Receiver, Balance {

        // The declaration of a concrete type in a contract interface means that
        // every Fungible Token contract that implements the FungibleToken interface
        // must define a concrete `Vault` resource that conforms to the `Provider`, `Receiver`,
        // and `Balance` interfaces, and declares their required fields and functions

        /// The total balance of the vault
        ///
        pub var balance: UFix64
        pub let tokenID: UInt64

        // The conforming type must declare an initializer
        // that allows prioviding the initial balance of the Vault
        //
        init(tokenID: UInt64, balance: UFix64)

        /// withdraw subtracts `amount` from the Vault's balance
        /// and returns a new Vault with the subtracted balance
        ///
        pub fun withdraw(amount: UFix64): @TokenVault {
            pre {
                self.balance >= amount:
                    "Amount withdrawn must be less than or equal than the balance of the TokenVault"
            }
            post {
                // use the special function `before` to get the value of the `balance` field
                // at the beginning of the function execution
                //
                self.balance == before(self.balance) - amount:
                    "New TokenVault balance must be the difference of the previous balance and the withdrawn TokenVault"

                 self.tokenID == before(self.tokenID):
                    "TokenVault returned does not match TokenVault ID"
            }
        }

        /// deposit takes a Vault and adds its balance to the balance of this Vault
        ///
        pub fun deposit(from: @TokenVault) {
            // Assert that the concrete type of the deposited vault is the same
            // as the vault that is accepting the deposit
            pre {
                from.isInstance(self.getType()): 
                    "Cannot deposit an incompatible token type"

                from.tokenID == self.tokenID:
                    "Deposited Token ID does not match TokenVault"
            }
            post {
                self.balance == before(self.balance) + before(from.balance):
                    "New TokenVault balance must be the sum of the previous balance and the deposited TokenVault"
            }
        }
    }

    // Interface that an account would commonly 
    // publish for their collection
    pub resource interface CollectionPublic {
        pub fun deposit(token: @TokenVault)
        pub fun getIDs(): [UInt64]
    }

    pub resource interface CollectionPrivate
    {
        pub fun borrowVault(id: UInt64): &TokenVault
    }

    // Requirement for the the concrete resource type
    // to be declared in the implementing contract
    //
    pub resource Collection: CollectionPublic {

        // Dictionary to hold the Vaults in the Collection
        pub var ownedVaults: @{UInt64: TokenVault}

        // deposit takes a Vault and adds it to the collections dictionary
        // and adds the ID to the id array
        pub fun deposit(token: @TokenVault)

        // getIDs returns an array of the IDs that are in the collection
        pub fun getIDs(): [UInt64]

        // Returns a borrowed reference to an Vault in the collection
        // so that the caller can read data and call methods from it
        pub fun borrowVault(id: UInt64): &TokenVault {
            pre {
                self.ownedVaults[id] != nil: "TokenVault does not exist in the collection!"
            }
            post {
                result.tokenID == id: "Incorrect tokenID returned!"
            }
        }
    }

    // createEmptyCollection creates an empty Collection
    // and returns it to the caller so that they can own Vaults
    pub fun createEmptyCollection(): @Collection {
        post {
            result.getIDs().length == 0: "The created collection must be empty!"
        }
    }

    /// createEmptyVault allows any user to create a new Vault that has a zero balance
    ///
    pub fun createEmptyTokenVault(tokenID: UInt64): @TokenVault {
        post {
            result.balance == 0.0: "The newly created TokenVault must have zero balance"
            result.tokenID == tokenID : "The newly created TokenVault must have correct tokenID"
        }
    }
}