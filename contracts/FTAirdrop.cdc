import FungibleToken from "./dependencies/FungibleToken.cdc"

// Contract to allow a caller to deposit tokens 
// upload a list of addresses that can claim 
// and the amount they can claim
// caller sets time limit during which he cannot withdraw the tokens
// after the time limit expires the claiming ends and the owner can withdraw any remaining tokens
pub contract Airdrop {

    // drops by ID 
    access(contract) let drops: @{UInt64:Drop}

    // unique id for each drop
    pub var nextDropID: UInt64

    // Create Drop Function
    //
    // User calls functions to create an airdrop, they receive the controller in return they can store. 
    //
    pub fun createDrop(tokens: @FungibleToken.Vault, startTime: UFix64, duration: UFix64, ftReceiverCap: Capability<&{FungibleToken.Receiver}>, claims: {Address:UFix64}): @DropController {
        pre {
            startTime >= getCurrentBlock().timestamp : "Start time cannot be in the past!"
            duration >= 300.0 : "Start time must be at least 5 minutes in the future!"
            tokens.balance > 0.0 : "Must have tokens available to claim!"
        }
        // create drop resource
        let drop <- create Drop(tokens: <- tokens, startTime: startTime, duration: duration, ftReceiverCap: ftReceiverCap)

        // insert in dictionary
        let nullResource
            <- self.drops.insert(key: self.nextDropID, <- drop)
        destroy nullResource

        // create controller resource
        let dropController <- create DropController(id: self.nextDropID)
        dropController.addClaims(addresses: claims)

        // increment id
        self.nextDropID = self.nextDropID + 1

        // return controller for owner to save in their storage
        return <- dropController
    }

    // Check Available Claims
    //
    // Returns all drop IDs and required ftType for a given address  
    //
    pub fun checkAvailableClaims(address: Address): {UInt64: Type} {
        let claimableDropIDs: {UInt64: Type} = {} 
        for key in self.drops.keys {
            let dropRef = &self.drops[key] as &Drop
            if dropRef.availableToClaimByAddress.containsKey(address) {
                claimableDropIDs.insert(key: key, dropRef.ftReceiverCap.getType()) // could insert {key: required FungibleTokenType
            }
        }
        return claimableDropIDs
    }

    // Claim Drop Function 
    //
    // Claims an amount for the address of the ft receiver cap provided 
    //
    pub fun claimDrop(dropID: UInt64, amount: UFix64, ftReceiverCap: Capability<&{FungibleToken.Receiver}>) {
        let dropRef = &self.drops[dropID] as &Drop
        dropRef.claim(amount: amount, ftReceiverCap: ftReceiverCap)
    }

    // Drop Resource
    //
    // Stores the tokens for the drop, endTime, and the owners receiver cap in case of return
    //
    pub resource Drop {
        pub let vault: @FungibleToken.Vault
        pub let ftReceiverCap: Capability<&{FungibleToken.Receiver}>
        pub let startTime: UFix64
        pub let endTime: UFix64
        pub let availableToClaimByAddress: {Address: UFix64}

        pub fun claim(amount:UFix64, ftReceiverCap: Capability<&{FungibleToken.Receiver}>) {
            let claimAddress = ftReceiverCap.address
            let receiverRef = ftReceiverCap.borrow()
            receiverRef?.deposit(from: <- self.vault.withdraw(amount: amount))
        }

        init(tokens: @FungibleToken.Vault, startTime: UFix64, duration: UFix64, ftReceiverCap: Capability<&{FungibleToken.Receiver}>) {
            pre {
                duration >= 360.0 // 5 min minimum, could be much higher but not much lower! 
            }
            self.vault <- tokens
            self.startTime = startTime
            self.endTime = startTime + duration
            self.ftReceiverCap = ftReceiverCap
            self.availableToClaimByAddress = {}
        }

        destroy() {
            destroy self.vault
        }
    }

    pub resource DropController {
        pub let id: UInt64

        pub fun addClaims(addresses: {Address: UFix64}) {
            let dropRef = &Airdrop.drops[self.id] as &Drop
            assert(getCurrentBlock().timestamp <= dropRef.startTime, message: "Cannot add addresses once claim has begun")
            var totalClaims = 0.0
            for key in addresses.keys {
                totalClaims = totalClaims + dropRef.availableToClaimByAddress[key]!
                assert(totalClaims <= dropRef.vault.balance, message: "More claims than balance available!")
                dropRef.availableToClaimByAddress.insert(key: key, addresses[key]!)
            }
        }

        pub fun withdrawFunds() {
            let dropRef = &Airdrop.drops[self.id] as &Drop
            assert(getCurrentBlock().timestamp < dropRef.endTime, message: "Drop has not ended yet!")
            let funds <- dropRef.vault.withdraw(amount: dropRef.vault.balance)
            dropRef.ftReceiverCap.borrow()?.deposit!(from: <- funds)
        }

        init(id: UInt64,) {
            self.id = id
        }

        destroy () {
            let dropRef = &Airdrop.drops[self.id] as &Drop
            if dropRef.vault.balance > 0.0 {
                self.withdrawFunds()
            }
        }
    }

    init() {
        self.drops <- {}
        self.nextDropID = 0
    }
}