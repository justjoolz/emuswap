import NonFungibleToken from "./dependencies/NonFungibleToken.cdc"

// Contract to allow a caller to deposit tokens 
// upload a list of addresses that can claim 
// and the amount they can claim
// caller sets time limit during which he cannot withdraw the tokens
// after the time limit expires the claiming ends and the owner can withdraw the tokens
pub contract Airdrop {

    // drops by ID 
    access(contract) let drops: @{UInt64:Drop}

    // unique id for each drop
    pub var nextDropID: UInt64

    // Create Drop Function
    //
    // User calls functions to create an airdrop, they receive the controller in return they can store. 
    //
    pub fun createDrop(tokens: @NonFungibleToken.Collection, startTime: UFix64, duration: UFix64, nftReceiverCap: Capability<&{NonFungibleToken.Receiver}>): @DropController {
        // create drop resource
        let drop <- create Drop(tokens: <- tokens, startTime: startTime, duration: duration, nftReceiverCap: nftReceiverCap)

        // insert in dictionary
        let nullResource
            <- self.drops.insert(key: self.nextDropID, <- drop)
        destroy nullResource

        // create controller resource
        let dropController <- create DropController(id: self.nextDropID)

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
        for id in self.drops.keys {
            let dropRef = &self.drops[id] as &Drop
            if dropRef.availableToClaimByAddress.containsKey(address) {
                claimableDropIDs.insert(key: id, dropRef.nftReceiverCap.getType()) // could insert {key: required FungibleTokenType
            }
        }
        return claimableDropIDs
    }

    // j00lz 2do make the above meta data with amount of tokens nfts available to claim too

    // Claim Drop Function 
    //
    // Claims an amount for the address of the ft receiver cap provided 
    //
    pub fun claimDrop(dropID: UInt64, amount: UInt64, nftReceiverCap: Capability<&{NonFungibleToken.Receiver}>) {
        let dropRef = &self.drops[dropID] as &Drop
        dropRef.claim(amount: amount, nftReceiverCap: nftReceiverCap)
    }

    // Drop Resource
    //
    // Stores the tokens for the drop, endTime, and the owners receiver cap in case of return
    //
    pub resource Drop {
        pub let collection: @NonFungibleToken.Collection
        pub let nftReceiverCap: Capability<&{NonFungibleToken.Receiver}>
        pub let startTime: UFix64
        pub let endTime: UFix64
        pub let availableToClaimByAddress: {Address: UInt64}

        pub fun claim(amount:UInt64, nftReceiverCap: Capability<&{NonFungibleToken.Receiver}>) {
            pre {
                amount > 0 : "must claim at least 1 nft!"
                getCurrentBlock().timestamp >= self.startTime : "Claim period has not opened"
                getCurrentBlock().timestamp <= self.endTime : "Claim period has closed"
            }
            let claimAddress = nftReceiverCap.address
            assert(self.availableToClaimByAddress.containsKey(claimAddress), message: "Address isn't on list!")
            let receiverRef = nftReceiverCap.borrow()
            // amount of nfts to claim or max
            var toClaim = amount <= self.availableToClaimByAddress[claimAddress]! ? amount : self.availableToClaimByAddress[claimAddress]!
            while toClaim > 0 {
                receiverRef?.deposit(token: <- self.collection.withdraw(withdrawID: self.collection.getIDs().removeLast()))
                self.availableToClaimByAddress[claimAddress] = self.availableToClaimByAddress[claimAddress]! - 1 
                toClaim = toClaim - 1
            }
            // clean up
            if self.availableToClaimByAddress[claimAddress] == 0 {
                self.availableToClaimByAddress.remove(key: claimAddress)
            } 
        }

        init(tokens: @NonFungibleToken.Collection, startTime: UFix64, duration: UFix64, nftReceiverCap: Capability<&{NonFungibleToken.Receiver}>) {
            pre {
                startTime >= getCurrentBlock().timestamp : "Start time cannot be in the past!"
                duration >= 360.0 // 5 min minimum, could be much higher but not much lower! 
            }
            self.collection <- tokens
            self.startTime = startTime
            self.endTime = startTime + duration
            self.nftReceiverCap = nftReceiverCap
            self.availableToClaimByAddress = {}
        }

        destroy() {
            destroy self.collection
        }
    }

    pub resource DropController {
        pub let id: UInt64

        pub fun addClaims(addresses: {Address: UInt64}) {
            let dropRef = &Airdrop.drops[self.id] as &Drop
            let nftsAvailable = UInt64(dropRef.collection.getIDs().length)
            var totalClaims = (0 as UInt64)
            for key in addresses.keys {
                totalClaims = totalClaims + addresses[key]!
                assert(totalClaims <= nftsAvailable, message: "More claims than NFTs!" )
                dropRef.availableToClaimByAddress.insert(key: key, addresses[key]!)
            }
        }

        pub fun withdrawRemainingNFTs() {
            let dropRef = &Airdrop.drops[self.id] as &Drop
            assert(getCurrentBlock().timestamp > dropRef.endTime, message: "Drop has not ended yet!")
            for id in dropRef.collection.getIDs() {
                let token <- dropRef.collection.withdraw(withdrawID: id)
                dropRef.nftReceiverCap.borrow()?.deposit!(from: <- token)
            }
        }

        init(id: UInt64,) {
            self.id = id
        }

        destroy () {
            let dropRef = &Airdrop.drops[self.id] as &Drop
            if dropRef.collection.getIDs().length > 0 {
                self.withdrawRemainingNFTs()
            }
            let completedDrop <- Airdrop.drops.remove(key: self.id)
            destroy completedDrop
        }
    }

    init() {
        self.drops <- {}
        self.nextDropID = 0
    }
}