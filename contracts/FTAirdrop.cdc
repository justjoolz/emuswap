import FungibleToken from "./dependencies/FungibleToken.cdc"

// Contract to allow a caller to deposit tokens 
// upload a list of addresses that can claim 
// and the amount they can claim
// caller sets time limit during which he cannot withdraw the tokens
// after the time limit expires the claiming ends and the owner can withdraw any remaining tokens
pub contract FTAirdrop {

    // drops by ID 
    access(contract) let drops: @{UInt64:Drop}

    // unique id for each drop
    access(contract) var nextDropID: UInt64

    // paths
    pub let DropControllerStoragePath: StoragePath

    // events
    pub event DropCreated(id: UInt64, address: Address, amount: UFix64)
    pub event DropClaimed(id: UInt64, address: Address, amount: UFix64)
    pub event DropDestroyed(id: UInt64)

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
        // store amount for event
        let amount = tokens.balance

        // create drop resource
        let drop <- create Drop(tokens: <- tokens, startTime: startTime, duration: duration, ftReceiverCap: ftReceiverCap)

        // insert in dictionary
        self.drops[self.nextDropID] <-! drop

        // create controller resource
        let dropController <- create DropController(id: self.nextDropID)
        dropController.addClaims(addresses: claims)

        // increment id
        self.nextDropID = self.nextDropID + 1

        emit DropCreated(id: dropController.id, address: ftReceiverCap.address, amount: amount)

        // return controller for owner to save in their storage
        return <- dropController
    }


    pub fun getDrops(): [UInt64] {
        return self.drops.keys
    }

    // Check Available Claims
    //
    // Returns all drop IDs and required ftType for a given address  
    //
    pub fun checkAvailableClaims(address: Address): AnyStruct {
        let claimableDropIDs:  [AnyStruct] = []
        for key in self.drops.keys {
            let dropRef = (&self.drops[key] as &Drop?)!
            if dropRef.availableToClaimByAddress.containsKey(address) {
                claimableDropIDs.append( {
                    "id": key,
                    "amount": dropRef.availableToClaimByAddress[address],
                    "type": dropRef.vault.getType().identifier
                })
            }
        }
        return claimableDropIDs
    }

    // Claim Drop Function 
    //
    // Claims full amount available for the address of the ft receiver cap provided 
    //
    pub fun claimDrop(dropID: UInt64, ftReceiverCap: Capability<&{FungibleToken.Receiver}>) {
        let dropRef = (&self.drops[dropID] as &Drop?) ?? panic("Drop ID Does not exist!")
        assert(dropRef.availableToClaimByAddress[ftReceiverCap.address] != nil, message: "Address has no available tokens to claim!")
        let amount = dropRef.claim(ftReceiverCap: ftReceiverCap)
        emit DropClaimed(id: dropID, address: ftReceiverCap.address, amount: amount)
    }

    // Drop Resource
    //
    // Stores the tokens for the drop, endTime, and the owners receiver cap in case of return
    //
    pub resource Drop {
        access(contract) let vault: @FungibleToken.Vault
        access(contract) let ftReceiverCap: Capability<&{FungibleToken.Receiver}>
        access(contract) let startTime: UFix64
        access(contract) let endTime: UFix64
        access(contract) let availableToClaimByAddress: {Address: UFix64}

        access(contract) fun addClaim(address: Address, amount: UFix64) {
            self.availableToClaimByAddress.insert(key: address, amount)
        }

        pub fun claim(ftReceiverCap: Capability<&{FungibleToken.Receiver}>): UFix64 {
            let claimAddress = ftReceiverCap.address
            let receiverRef = ftReceiverCap.borrow()
            let amount = self.availableToClaimByAddress[claimAddress] ?? panic("This address does not have any tokens to claim!")
            receiverRef?.deposit(from: <- self.vault.withdraw(amount: amount))
            self.availableToClaimByAddress[ftReceiverCap.address] = nil // self.availableToClaimByAddress[ftReceiverCap.address]! - amount
            return amount
        }

        pub fun totalClaims(): UFix64 {
            var total = 0.0
            for key in self.availableToClaimByAddress.keys {
                total = total + self.availableToClaimByAddress[key]!
            }
            return total
        }

        init(tokens: @FungibleToken.Vault, startTime: UFix64, duration: UFix64, ftReceiverCap: Capability<&{FungibleToken.Receiver}>) {
            pre {
                duration >= 360.0
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


    // DropController resource
    //
    // Used to manage a drop
    //
    pub resource DropController {
        access(contract) let id: UInt64

        // addClaims function
        //
        // Drop owner can add a list of addresses and claim amounts 
        // Total must be less than funds deposited
        //
        pub fun addClaims(addresses: {Address: UFix64}) {
            let dropRef = (&FTAirdrop.drops[self.id] as &Drop?)!
            assert(getCurrentBlock().timestamp <= dropRef.startTime, message: "Cannot add addresses once claim has begun")
            var totalClaims = dropRef.totalClaims()
            for key in addresses.keys {
                dropRef.addClaim(address: key, amount: addresses[key]!)
                totalClaims = totalClaims + dropRef.availableToClaimByAddress[key]!
                assert(totalClaims <= dropRef.vault.balance, message: "More claims than balance available!")
                dropRef.addClaim(address: key, amount: addresses[key]!)
            }
        }

        // withdraw funds function
        //
        // once the drop has finished
        // owner can withdraw any unclaimed funds to their  ft receiver provided on creation
        //
        pub fun withdrawFunds() {
            let dropRef = (&FTAirdrop.drops[self.id] as &Drop?)!
            assert(getCurrentBlock().timestamp < dropRef.endTime, message: "Drop has not ended yet!")
            let funds <- dropRef.vault.withdraw(amount: dropRef.vault.balance)
            dropRef.ftReceiverCap.borrow()?.deposit!(from: <- funds)
        }

        // deposit funds function
        //
        // owner can deposit additional funds before the drop starts
        //
        pub fun depositFunds(funds: @FungibleToken.Vault) {
            let dropRef = (&FTAirdrop.drops[self.id] as &Drop?)!
            assert(getCurrentBlock().timestamp < dropRef.startTime, message: "Drop has already started!")
            dropRef.vault.deposit(from: <- funds)
        }

        // initalized with an ID to match the escrowed drop resource
        init(id: UInt64) {
            self.id = id
        }

        // owner can destroy their controller returning all funds to the provided ft receiver
        destroy () {
            let dropRef = (&FTAirdrop.drops[self.id] as &Drop?)!
            assert(getCurrentBlock().timestamp >= dropRef.endTime, message: "Cannot destroy before endtime is reached")
            if dropRef.vault.balance > 0.0 {
                self.withdrawFunds()
            }
            assert(dropRef.vault.balance == 0.0, message: "Funds remaining in referenced drop, cannot destroy controller")
            FTAirdrop.drops[self.id] <-! nil

            emit DropDestroyed(id: self.id)
        }
    }

    pub resource DropControllerCollection {
        access(contract) var drops: @{UInt64: DropController}

        pub fun deposit(drop: @DropController) {
            self.drops[drop.uuid] <-! drop
        }

        pub fun clean(id: UInt64) {
            destroy self.drops.remove(key: id)
        }

        init() {
            self.drops <- {}
        }

        destroy () {
            destroy self.drops
        }
    }

    pub fun createEmptyDropCollection(): @DropControllerCollection {
        return <- create DropControllerCollection() 
    }

    init() {
        self.DropControllerStoragePath = /storage/FTAirDropController
        self.drops <- {}
        self.nextDropID = 0
    }
}