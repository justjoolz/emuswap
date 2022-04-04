import NonFungibleToken from "./dependencies/NonFungibleToken.cdc"
import FungibleToken from "./dependencies/FungibleToken.cdc"
import FungibleTokens from "./dependencies/FungibleTokens.cdc"
import EmuToken from "./EmuToken.cdc"
import EmuSwap from "./exchange/EmuSwap.cdc"

// Liquidity Mining
//
// Admin can create Farms that match Farm IDs from EmuSwap
//
// Users can deposit LP Tokens and receive rewards
//
// https://dev.sushi.com/sushiswap/contracts/masterchefv2

// Supports multiple reward pools.
// Each reward pool has a vault and an emissions schedule
// Each reward pool can be NFT gated
// Each reward pool has has a field specifying weighted distribution for each farm (farmWeightsByID)
//
// Each Token Swap Pair on EmuSwap has a unique Farm associated
// They can be created only by the Admin
// 
// Each Farm tracks users lp + nft stakes
// Each farm has a field corresponding to each reward pool
// When a new reward pool is created, all the Fields for each Farm are updated 
// For each field / reward pool tracks the rewardsTokensPerSecond, lastRewardTimestamp and totalAccumulatedTokensPerShare   
// Users

// 

pub contract StakingRewards {
    access(contract) var rewardPoolsByID: @{UInt64: RewardPool} // these have unique IDs, as it's possible to have multiple pools with the same reward token but NFT gated 
    access(contract) var nextRewardPoolID: UInt64

    // Dictionary of Farms by EmuSwap.Farm.ID
    access(contract) let farmsByID: @{UInt64:Farm}          // Farm Resource indexed by the ID of their EmuSwap pool 

    // Paths
    pub let AdminStoragePath: StoragePath
    pub let CollectionStoragePath: StoragePath

    // Events
    pub event NewFarmCreated(farmID: UInt64)
    pub event EmissionRateUpdated(newRate: UFix64)
    pub event TokensStaked(address: Address, amountStaked: UFix64, totalStaked: UFix64)
    pub event TokensUnstaked(address: Address, amountUnstaked: UFix64, totalStaked: UFix64)
    pub event RewardsClaimed(address: Address, tokenType: String, amountClaimed: UFix64, rewardDebt: Fix64, totalRemaining: UFix64)

    // Testing Mock time
    access(contract) var mockTime: Bool
    access(contract) var mockTimestamp: UFix64

    // Reward Pool Struct
    //
    // All Staking rewards are issued from a rewards pool 
    // Each token that is used as incentives are stored here
    // These resources are only ever stored in an access(contract) field and there are no functions that return any reference to them
    // so pub(set) is safe to use 
    //
    pub resource RewardPool {
        pub let vault: @FungibleToken.Vault
        pub let farmWeightsByID: {UInt64: UFix64}
        pub let emissionDetails: AnyStruct{IEmissionDetails} // used to pass in function for custom emissions rates
        
        pub var accessNFTsAccepted: [String] 
        pub(set) var totalWeight: UFix64
        pub(set) var rewardsGenesisTimestamp: UFix64

        init(tokens: @FungibleToken.Vault, emissionDetails: {IEmissionDetails}, farmWeightsByID: {UInt64: UFix64}, accessNFTsAccepted: [String]) {
            self.accessNFTsAccepted = accessNFTsAccepted
            self.vault <- tokens
            self.rewardsGenesisTimestamp = 0.0
            self.emissionDetails = emissionDetails // need to assert this has correct functions
            self.farmWeightsByID = farmWeightsByID
            
            var totalWeight = 0.0
            for id in farmWeightsByID.keys { 
                totalWeight = totalWeight + farmWeightsByID[id]!
            }
            self.totalWeight = totalWeight
        }

        destroy() {
            destroy self.vault
        }

        pub fun acceptsNFTsByKeys(_ keys: [String]): Bool {
            if self.accessNFTsAccepted.length == 0 { return true }
            var i = 0
            while i < keys.length {
                if self.accessNFTsAccepted.contains(keys[i]) {
                    return true
                }
                i = i + 1
            }
            return false
        }

        pub fun acceptsNFTs(_ nfts: &[NonFungibleToken.NFT]): Bool {
            if self.accessNFTsAccepted.length == 0 { return true }  // if empty means no nft is required
            let test: Bool = false
            while nfts.length > 0 {
                let nft = &nfts.removeFirst() as &NonFungibleToken.NFT
                let identifier = nft.getType().identifier
                if self.accessNFTsAccepted.contains(identifier) {
                    return true
                }
            }
            return false
        }

        pub fun addNFT(nftIdentifier: String) {
            self.accessNFTsAccepted.append(nftIdentifier)
        }

        pub fun removeNFT(index: UInt64) {
            self.accessNFTsAccepted.remove(at: index)
        }

    }

    // Field Structure
    //
    // The only Field structs that matter are the ones stored in a Farm resources access(contract) fields dictionary field 
    // Therefore it's safe for them to have publicly settable fields (as the public can never access the Field from the dictionary)
    //
    pub struct Field {
        pub(set) var totalAccumulatedTokensPerShare: UFix64     // accJoePerShare 
        
        init(totalAccumulatedTokenPerShare: UFix64) {
            self.totalAccumulatedTokensPerShare = totalAccumulatedTokenPerShare
        }
    } 

    // Farm resource
    //
    // Stored in Farms variable and a reference is never made accessible directly
    //
    pub resource Farm {
        access(contract) let emuSwapPoolID: UInt64
        access(contract) let accessNFTsAccepted: [String]
        access(contract) let stakes: @{Address:Stake}            // Dictionary of Stakes by stakers Address
        access(contract) let fields: {UInt64: Field}
        access(contract) var lastRewardTimestamp: UFix64         // Last time rewards were calculated
        access(contract) var totalStaked: UFix64

        init(poolID: UInt64) {
            self.stakes <- {}
            self.fields = {}

            // Populate fields to match each existing reward pool
            var i: UInt64 = 0
            while i < UInt64(StakingRewards.rewardPoolsByID.length) {
                let rp = &StakingRewards.rewardPoolsByID[i] as &RewardPool
                self.fields[i] = Field(totalAccumulatedTokenPerShare: 0.0)
                i = i + 1
            }

            self.totalStaked = 0.0
            self.lastRewardTimestamp = StakingRewards.now()
            self.emuSwapPoolID = poolID
            
            self.accessNFTsAccepted = self.getAllAccessNFTsAccepted()
        }

        destroy () {
            destroy self.stakes
        }

        // Update Farm
        //
        // Main internal function that is called every time there is a change to the Farm
        // (tokens staked or unstaked)
        //
        access(contract) fun updateFarm() {
            let now = StakingRewards.now()
            
            if now <= self.lastRewardTimestamp {    // already up to date
                self.lastRewardTimestamp = now
                return 
            }

            if self.totalStaked == 0.0 {   // when first stake is being deposited.... nothing staked so nothing paid out
                self.lastRewardTimestamp = now
                return
            }
            
            let period = now - self.lastRewardTimestamp

            for rewardPoolID in self.fields.keys { 
                let fieldRef = &self.fields[rewardPoolID] as &Field
                let rewardRef = &StakingRewards.rewardPoolsByID[rewardPoolID] as &RewardPool

                // Calculate reward  
                let rewardTokensPerSecond = rewardRef.emissionDetails.getCurrentEmissionRate(genesisTS: rewardRef.rewardsGenesisTimestamp)
                let farmWeight = rewardRef.farmWeightsByID[self.emuSwapPoolID]! / rewardRef.totalWeight  
                let reward = period * rewardTokensPerSecond * farmWeight

                // Update field                
                fieldRef.totalAccumulatedTokensPerShare = fieldRef.totalAccumulatedTokensPerShare + (reward / self.totalStaked) // original splits this between dev treasury and farm
                self.lastRewardTimestamp = now
            }
        }

        // Get Pending Rewards Function
        //
        // Gets the total Pending rewards for an address
        // To be called by front end UI and used in metadata
        //
        pub fun getPendingRewards(address: Address): {UInt64: Fix64} {
            let pendingRewards: {UInt64: Fix64} = {}
            let now = StakingRewards.now()
            let stakeRef = &self.stakes[address] as &Stake

            for rewardPoolID in self.fields.keys {
                let field = self.fields[rewardPoolID]!
                let rewardRef = &StakingRewards.rewardPoolsByID[rewardPoolID] as &RewardPool
                var totalAccumulatedTokensPerShare = field.totalAccumulatedTokensPerShare
                
                if (now > self.lastRewardTimestamp) && (stakeRef.lpTokenVault.balance > 0.0) { // calculate unclaimed tokens since last reward payment
                    let delta = now - self.lastRewardTimestamp
                    let farmWeight = rewardRef.farmWeightsByID[stakeRef.lpTokenVault.tokenID]! / rewardRef.totalWeight
                    let rewardTokensPerSecond = rewardRef.emissionDetails.getCurrentEmissionRate(genesisTS: rewardRef.rewardsGenesisTimestamp)
                    let reward = delta * rewardTokensPerSecond * farmWeight
                    totalAccumulatedTokensPerShare = field.totalAccumulatedTokensPerShare  + (reward / self.totalStaked)
                }
                let pending = Fix64(stakeRef.lpTokenVault.balance * totalAccumulatedTokensPerShare ) - stakeRef.rewardDebtByID[rewardPoolID]!
                pendingRewards.insert(key: rewardPoolID, pending)
            }
            return pendingRewards
        }
        
        // Stake function
        //
        // User can deposit their lpTokens and send a receiver Capability that will receive the tokens when withdrawing
        // In return they get a stake controller resource to withdraw to use as reference to withdraw their stake.
        //
        pub fun stake(lpTokens: @FungibleTokens.TokenVault, lpTokensReceiverCap: Capability<&{FungibleTokens.CollectionPublic}>, rewardsReceiverCaps: [Capability<&{FungibleToken.Receiver}>], nftReceiverCaps: [Capability<&{NonFungibleToken.CollectionPublic}>], nfts: @[NonFungibleToken.NFT]): @StakeController? {    
            pre {
                // self.accessNFTsAccepted.length == 0 && nfts != nil : "NFT not required for this Farm."
                // self.stakes.containsKey(lpTokensReceiverCap.address) && nft != nil : "NFT already provided!" // need to check for all nfts across rewards pools
                // self.accessNFTsAccepted.length > 0 
                //    && !self.accessNFTsAccepted.contains(nft.getType().identifier) : "NFT provided is not of required type for this farm!"
            }
            self.updateFarm()
            
            // special case first ever stake sets genesis reward timestamp of first ever reward pool... all future pools must have a genesis timestamp starting time provided on creation
            if self.stakes.length == 0 {
                let field = self.fields[0]!
                let rewardRef = &StakingRewards.rewardPoolsByID[0] as &RewardPool
                rewardRef.rewardsGenesisTimestamp = self.lastRewardTimestamp
            }
            
            // Get LP Token ID
            let id = lpTokens.tokenID
            // Get amount of tokens to add to stake
            let amountStaked = lpTokens.balance

            // Update users stake 
            if !self.stakes.containsKey(lpTokensReceiverCap.address) { // New Stake
                let rewardDebtByID: {UInt64: Fix64} = {}

                // calculate reward debts for each field/reward pool
                for poolID in StakingRewards.rewardPoolsByID.keys {
                    let field = self.fields[poolID]!
                    let rewardPoolRef = &StakingRewards.rewardPoolsByID[poolID] as &RewardPool
                    
                    if rewardPoolRef.accessNFTsAccepted.length == 0 || rewardPoolRef.acceptsNFTs(&nfts as &[NonFungibleToken.NFT]) { // if no nft required or accepted nft deposited    
                        let rewardDebt = Fix64(amountStaked * field.totalAccumulatedTokensPerShare)
                        rewardDebtByID[poolID] = rewardDebt
                    }
                }
            
                let newStake <- create Stake(lpTokens: <- lpTokens, rewardDebt: rewardDebtByID, lpTokenReceiverCap: lpTokensReceiverCap, rewardsReceiverCaps: rewardsReceiverCaps, nfts: <- nfts, nftReceiverCaps: nftReceiverCaps)
                
                // Insert into the Farms stakes field
                self.stakes[lpTokensReceiverCap.address] <-! newStake

                // update Farm total staked
                self.totalStaked = self.totalStaked + amountStaked

                emit TokensStaked(address: lpTokensReceiverCap.address, amountStaked: amountStaked, totalStaked: self.totalStaked)

                // return stake controller for user to access their tokens
                return <- create StakeController(id: id, lpTokenReceiverCap: lpTokensReceiverCap, rewardsReceiverCaps: rewardsReceiverCaps) // id needs to be unique per user and per Farm
            } 

            else { // user already has an existing stake in this farm
                let stakeRef = &self.stakes[lpTokensReceiverCap.address] as &Stake        
                // add to existing stake
                stakeRef.lpTokenVault.deposit(from: <-lpTokens)

                // deposit nfts
                while nfts.length > 0 {
                    let nft <- nfts.removeFirst()
                    assert(stakeRef.nfts[nft.getType().identifier] == nil, message: "Duplicate NFT type detected, only 1 nft per collection can be staked.")
                    stakeRef.nfts[nft.getType().identifier] <-! nft
                }
                destroy nfts // empty :)
                                
                // update Farm total
                self.totalStaked = self.totalStaked + amountStaked

                // calculate reward debt for all fields of the farm
                let rewardDebtByID: {UInt64: Fix64} = {}
                for poolID in StakingRewards.rewardPoolsByID.keys {
                    let field = self.fields[poolID]!
                    let rewardPoolRef = &StakingRewards.rewardPoolsByID[poolID] as &RewardPool
                    if rewardPoolRef.acceptsNFTsByKeys(stakeRef.getNFTIdentifiers()) {
                        rewardDebtByID[poolID] = stakeRef.rewardDebtByID[poolID]! + Fix64(amountStaked * field.totalAccumulatedTokensPerShare)
                    }
                }
                stakeRef.setRewardDebt(rewardDebtByID)

                emit TokensStaked(address: lpTokensReceiverCap.address, amountStaked: amountStaked, totalStaked: self.totalStaked)
                return nil // no need to give them a new StakeController
            }           
        }

        // Unstake Function
        //
        // Unstake an amount of Staked LP Tokens
        // access controlled through passing a staking ref resource to prove ownership
        //
        pub fun unstake(amount: UFix64, stakeControllerRef: &StakeController) {
            pre {
                stakeControllerRef.farmID == self.emuSwapPoolID : "Incorrect Stake controller for this Farm!"
                stakeControllerRef.lpTokenReceiverCap.check() : "invalid token receiver cap?!"                                                                                                                                          // j00lz lpTokenReceiver is stored in 2 places... can just store in the stake itself and not in the controller? or vice versa?
            }

            let address = stakeControllerRef.lpTokenReceiverCap.address 
            assert( amount <= self.stakes[address]?.lpTokenVault?.balance!, message: "Insufficient LP Tokens available to withdraw. ".concat(
                amount.toString()).concat(" ").concat( 
                    (self.stakes[address]?.lpTokenVault?.balance!).toString()))

            // get reference to stake
            let stakeRef = stakeControllerRef.borrowStake()
            
            // if withdrawing everything return their nfts
            if stakeRef.lpTokenVault.balance == 0.0 {
                for nftIdentifier in self.accessNFTsAccepted {
                    let nftReceiver = stakeRef.nftReceiverCapsByID[nftIdentifier]!.borrow()
                    nftReceiver?.deposit(token: <- stakeRef.withdrawNFT(identifier: nftIdentifier)!)
                }
            }
            
            // Withdraw requested amount of LP Tokens and return to the user
            let receiverRef = stakeControllerRef.lpTokenReceiverCap.borrow()
            let tokens <- stakeRef.lpTokenVault.withdraw(amount: amount)
            receiverRef?.deposit!(from: <- tokens)

            // payout rewards
            for poolID in StakingRewards.rewardPoolsByID.keys {
                let field = self.fields[poolID]!            
                let rewardPoolRef = &StakingRewards.rewardPoolsByID[poolID] as &RewardPool
                if rewardPoolRef.acceptsNFTsByKeys(stakeRef.getNFTIdentifiers()) {
                    stakeRef.rewardDebtByID[poolID] = stakeRef.rewardDebtByID[poolID]! - Fix64(amount * field.totalAccumulatedTokensPerShare)
                }
            }

            // update Farm total
            self.totalStaked = self.totalStaked - amount

            // j00lz test moving this to beginning of the function
            self.updateFarm()
        }


        // Claim Rewards
        // j00lz todo needs optimizing (repeated call of getPendingRewards)
        // can consider refactoring these 2 functions into the stake resource....
        pub fun claimRewards(stakeControllerRef: &StakeController) {
            self.updateFarm()
            let stakeRef = stakeControllerRef.borrowStake()
            
            for poolID in StakingRewards.rewardPoolsByID.keys {
                let field = self.fields[poolID]!
                let accumulatedTokens = stakeRef.lpTokenVault.balance * field.totalAccumulatedTokensPerShare
                let pending = Fix64(accumulatedTokens) - stakeRef.rewardDebtByID[poolID]!

                if stakeRef.rewardsReceiverCaps[poolID] != nil { // user has provided the correct receiver already... if there is a new reward pool added the user will need to setup and provide a new matching receiver to claim 
                    // update reward debt
                    stakeRef.rewardDebtByID[poolID] = Fix64(accumulatedTokens)
                    // distribute pending
                    let rewards <- StakingRewards.rewardPoolsByID[poolID]?.vault?.withdraw(amount: UFix64(pending))!
                    let rewardTokenType = rewards.getType().identifier
                    stakeRef.rewardsReceiverCaps[poolID]?.borrow()!!.deposit(from: <-rewards)
                    emit RewardsClaimed(address: stakeRef.rewardsReceiverCaps[0]!.address, tokenType: rewardTokenType, amountClaimed: UFix64(pending), rewardDebt: stakeRef.rewardDebtByID[poolID]!, totalRemaining: StakingRewards.rewardPoolsByID[poolID]?.vault?.balance!)
                } 
            }
        }

        pub fun readStakes(): {Address: StakeInfo} {
            let stakesMeta: {Address:StakeInfo} = {}
            for key in self.stakes.keys {
                stakesMeta.insert(
                    key: key,
                    StakeInfo(
                        &self.stakes[key] as &Stake,
                        farm: &self as &Farm
                    )
                )
            }
            return stakesMeta
        }

        pub fun getAllAccessNFTsAccepted(): [String] {
            let accessNFTsAccepted: [String] = []
            for rewardPoolID in StakingRewards.rewardPoolsByID.keys {
                let rewardPoolRef = &StakingRewards.rewardPoolsByID[rewardPoolID] as &RewardPool
                for nftIdentifier in rewardPoolRef.accessNFTsAccepted {
                    if !accessNFTsAccepted.contains(nftIdentifier) {
                        accessNFTsAccepted.append(nftIdentifier)
                    }
                }
            }
            return accessNFTsAccepted
        }

    }

    // Stake Resource
    //
    // Holds the staked funds of the user. (lp)
    // A receiver Caabiity to return their funds
    // as well as an access NFT if required by the farm
    // total reward debt calculated 
    // 
    pub resource Stake {

        access(contract) var lpTokenVault: @FungibleTokens.TokenVault
        access(contract) var nfts: @{String: NonFungibleToken.NFT}
        access(contract) var nftReceiverCapsByID: {String: Capability<&{NonFungibleToken.CollectionPublic}>}
        access(contract) var rewardDebtByID: {UInt64: Fix64}
        access(contract) var lpTokenReceiverCap: Capability<&{FungibleTokens.CollectionPublic}>
        access(contract) var rewardsReceiverCaps: {UInt64: Capability<&{FungibleToken.Receiver}>}

        init(lpTokens: @FungibleTokens.TokenVault, rewardDebt: {UInt64: Fix64}, lpTokenReceiverCap: Capability<&{FungibleTokens.CollectionPublic}>, rewardsReceiverCaps: [Capability<&{FungibleToken.Receiver}>], nfts: @[NonFungibleToken.NFT], nftReceiverCaps: [Capability<&{NonFungibleToken.CollectionPublic}>]) {
            self.lpTokenVault <- lpTokens
            self.lpTokenReceiverCap = lpTokenReceiverCap

            self.rewardsReceiverCaps = {}
            for i, rewardReceiverCap in rewardsReceiverCaps {
                self.rewardsReceiverCaps.insert(key: UInt64(i), rewardReceiverCap)
            }

            self.rewardDebtByID = rewardDebt
            self.nftReceiverCapsByID = {}
            self.nfts <- {}
            while nfts.length > 0 {
                let nft <- nfts.removeFirst()
                let identifier = nft.getType().identifier
                self.nfts[identifier] <-! nft
                self.nftReceiverCapsByID[identifier] = nftReceiverCaps.removeFirst()
            }
            destroy nfts // all gone :)
        }

        pub fun getNFTIdentifiers(): [String] {
            let keys: [String] = []
            for key in self.nfts.keys {
                keys.append(key)
            }
            return keys
        }

        pub fun withdrawNFT(identifier: String): @NonFungibleToken.NFT? {
            return <- self.nfts.remove(key: identifier)
        }        
        
        pub fun depositNFT(nft: @NonFungibleToken.NFT) {
            pre {
                !self.nfts.containsKey(nft.getType().identifier): "NFT of this collection already staked!"
            }
            self.nfts[nft.getType().identifier] <-! nft
        }

        access(contract) fun setRewardDebt(_ debt: {UInt64: Fix64}) {
            self.rewardDebtByID = debt 
        }

        destroy () {
            destroy self.lpTokenVault
            destroy self.nfts
        }
    }


    pub struct StakeInfo {
        pub let address: Address
        pub let balance: UFix64
        pub let rewardDebtByID: {UInt64: Fix64}
        pub let pendingRewards: {UInt64: Fix64} 
        init(_ stake: &Stake, farm: &Farm) {
            self.address = stake.lpTokenReceiverCap.address
            self.balance = stake.lpTokenVault.balance
            self.rewardDebtByID = stake.rewardDebtByID
            self.pendingRewards = farm.getPendingRewards(address: self.address)
        }
    }

    // Stake Controller Resource
    //
    // User's reference to their stake.
    //
    pub resource StakeController {
        pub let farmID: UInt64

        pub let accessNFTsAccepted: [String] // array of fully qualified identifiers of accepted booster NFTs

        pub let lpTokenReceiverCap: Capability<&{FungibleTokens.CollectionPublic}>
        pub let rewardsReceiverCaps: [Capability<&{FungibleToken.Receiver}>]

        // borrow stake function
        //
        // This is the only way to borrow a reference to a stake
        // only the owner of stakecontroller resource can borrow the linked stake
        //
        pub fun borrowStake(): &Stake {
            let farmRef = StakingRewards.borrowFarm(id: self.farmID)!
            let stakeRef = &farmRef.stakes[self.lpTokenReceiverCap.address] as &Stake
            return stakeRef
        }

        init(id: UInt64, lpTokenReceiverCap: Capability<&{FungibleTokens.CollectionPublic}>, rewardsReceiverCaps: [Capability<&{FungibleToken.Receiver}>]) {
            self.farmID = id
            self.lpTokenReceiverCap = lpTokenReceiverCap
            self.rewardsReceiverCaps = rewardsReceiverCaps
            self.accessNFTsAccepted = StakingRewards.farmsByID[id]?.accessNFTsAccepted!
        }

    }

    // Stake Controller Collection
    //
    //
    pub resource StakeControllerCollection { 
        pub var ownedStakeControllers: @{UInt64:StakeController}

        pub fun deposit(stakeController: @StakeController) {
            pre {
                self.ownedStakeControllers[stakeController.farmID] == nil : "Cannot have multiple controllers for same farm!"
            }
            self.ownedStakeControllers[stakeController.farmID] <-! stakeController
        }

        pub fun withdraw(id: UInt64): @StakeController? {
            return <- self.ownedStakeControllers.remove(key: id)
        }

        pub fun borrow(id: UInt64): &StakeController? {
            return &self.ownedStakeControllers[id] as &StakeController
        }

        init() {
            self.ownedStakeControllers <- {}
        }
        destroy () {
            destroy self.ownedStakeControllers
        }
    }

     // Admin resource
    //
    // only admin can create reward pools, create farms, update pool weights 
    //
    pub resource Admin {

        // Create Rewards Pool
        //
        // 
        //
        pub fun createRewardPool(tokens: @FungibleToken.Vault, emissionDetails: AnyStruct{IEmissionDetails}, farmWeightsByID: {UInt64: UFix64}, accessNFTsAccepted: [String]) {
            let poolID = StakingRewards.nextRewardPoolID
            let nullResorce <- 
                StakingRewards.rewardPoolsByID.insert(
                    key: poolID, 
                    <- create RewardPool(
                        tokens: <- tokens, 
                        emissionDetails: emissionDetails, 
                        farmWeightsByID: farmWeightsByID,
                        accessNFTsAccepted: accessNFTsAccepted
                    ) 
                )
            destroy nullResorce

            StakingRewards.nextRewardPoolID = StakingRewards.nextRewardPoolID + 1

             for id in StakingRewards.farmsByID.keys {
                let farmRef = &StakingRewards.farmsByID[id] as &Farm
                farmRef.fields[poolID] = Field(totalAccumulatedTokenPerShare: 0.0)
            }
            // emit RewardPoolCreated()
        }

        // fun deposit reward tokens
        //
        // creates new reward pool if tokens are of new type
        //
        pub fun depositRewardTokens(rewardPoolID: UInt64, tokens: @FungibleToken.Vault ) {
            let tokenIdentifier = tokens.getType().identifier
            StakingRewards.rewardPoolsByID[rewardPoolID]?.vault?.deposit!(from: <- tokens)
            // emit RewardPoolToppedUp()
        }

        pub fun addNFT(rewardPoolID: UInt64, nftIdentifier: String) {
            StakingRewards.rewardPoolsByID[rewardPoolID]?.addNFT(nftIdentifier: nftIdentifier)
        }

        pub fun removeNFT(rewardPoolID: UInt64, index: UInt64) {
            StakingRewards.rewardPoolsByID[rewardPoolID]?.removeNFT(index: index)
        }

        pub fun createFarm(poolID: UInt64) {
            pre {
                EmuSwap.getPoolIDs().contains(poolID) : "Pool does not exist on EmuSwap!"
                StakingRewards.farmsByID[poolID] == nil : "Farm already exists for this EmuSwap Liquidity Pool!"
            }
            let newFarm <- create Farm(poolID: poolID)
            StakingRewards.farmsByID[poolID] <-! newFarm
            
            emit NewFarmCreated(farmID: poolID)
        }

        pub fun updateFarmWeightForRewardPool(rewardPoolID: UInt64, farmID: UInt64, newWeight: UFix64) {
            let rewardRef = &StakingRewards.rewardPoolsByID[rewardPoolID] as &RewardPool
            let oldWeight = rewardRef.farmWeightsByID[farmID]!

            rewardRef.farmWeightsByID[farmID] = newWeight
            rewardRef.totalWeight = rewardRef.totalWeight - oldWeight + newWeight
        }

         // toggles use of mocktime
        pub fun toggleMockTime() {
            StakingRewards.mockTime = !StakingRewards.mockTime
            log("TOGGLING MOCK TIME!")
            log(StakingRewards.mockTime)
        }

        // updates mock time by delta (ffwd)
        pub fun updateMockTimestamp(delta: UFix64) {
            StakingRewards.mockTimestamp = StakingRewards.mockTimestamp + delta
            log("new time stamp")
            log(StakingRewards.mockTimestamp)
        }
    }

    // Farm Meta
    //
    // All Metadata of current state of a Farm.
    //
    pub struct FarmMeta {
        pub let id: UInt64;                     // ID of LP tokens from Emuswap.
        pub let stakes: {Address: StakeInfo}
        pub let totalStaked: UFix64
        pub let lastRewardTimestamp: UFix64
        pub let farmWeightsByID: {UInt64: UFix64}
        pub let rewardTokensPerSecondByID: {UInt64: UFix64} 
        pub let totalAccumulatedTokensPerShareByID: {UInt64: UFix64} 

        init(_ farmRef: &Farm) {
            self.id = farmRef.emuSwapPoolID
            self.stakes = farmRef.readStakes()
            self.totalStaked = farmRef.totalStaked
            self.lastRewardTimestamp = farmRef.lastRewardTimestamp
            self.farmWeightsByID = {}
            self.rewardTokensPerSecondByID = {}
            self.totalAccumulatedTokensPerShareByID = {}

            for poolID in StakingRewards.rewardPoolsByID.keys {
                let fieldRef = &farmRef.fields[poolID] as &Field
                let rewardPoolRef = &StakingRewards.rewardPoolsByID[poolID] as &RewardPool
                self.farmWeightsByID[poolID] = rewardPoolRef.farmWeightsByID[self.id]!
                self.rewardTokensPerSecondByID[poolID] = rewardPoolRef.emissionDetails.getCurrentEmissionRate(genesisTS: rewardPoolRef.rewardsGenesisTimestamp)
                self.totalAccumulatedTokensPerShareByID[poolID] = fieldRef.totalAccumulatedTokensPerShare
            }
        }        
    }

    pub fun createStakingControllerCollection(): @StakeControllerCollection {
        return <- create StakeControllerCollection()
    }

    pub fun getFarmMeta(id: UInt64): FarmMeta? {
        let farmRef = &StakingRewards.farmsByID[id] as &Farm
        if farmRef != nil {
            return FarmMeta(farmRef)
        }
        return nil
    }

    pub fun borrowFarm(id: UInt64): &Farm? {
        if self.farmsByID.keys.contains(id) {
            return &self.farmsByID[id] as &Farm
        } 
        return nil
    }
   
    pub struct interface IEmissionDetails {
        pub fun getCurrentEmissionRate(genesisTS: UFix64): UFix64 // A function that returns an emission rate relative to a given genesis timestamp
    } 

    // General purpose structure to return a decaying rate over time
    //
    pub struct DecayingEmission: IEmissionDetails {
        pub let epochLength: UFix64
        pub let totalEpochs: UFix64
        pub let decay: UFix64

        init(epochLength: UFix64, totalEpochs: UFix64, decay: UFix64) {
            self.epochLength = epochLength
            self.totalEpochs = totalEpochs
            self.decay = decay
        }

        pub fun getCurrentEmissionRate(genesisTS: UFix64): UFix64 {
            let epochLength = self.epochLength // 28.0 * 24.0 * 60.0 * 60.0
            let decay = self.decay // 0.05388176 // for 31days use: 0.05964249            
            let genesisTimestamp = genesisTS == 0.0 ? StakingRewards.now() : genesisTS            
            let elapsedTime = StakingRewards.now() - genesisTimestamp
            
            var currentEpoch = elapsedTime / epochLength

            if currentEpoch > self.totalEpochs {
                return 1.0
            }

            var rate = 1.0
            while currentEpoch > 1.0 {
                rate = rate * (1.0-decay)
                currentEpoch = currentEpoch - 1.0
            }

            return rate
        }
    }

    // getCurrentEpoch 
    //
    // returns current epoch (not rounded)
    //
    pub fun getCurrentEpoch(genesisTimestamp: UFix64): UFix64 {
        let epochLength = 28.0 * 24.0 * 60.0 * 60.0 
        let now = StakingRewards.now()        
        let elapsedTime = now - genesisTimestamp
        var currentEpoch = elapsedTime / epochLength
        return currentEpoch
    }

    // Now function
    //
    // Timestamp always provided by now function
    // includes option for mock time.
    //   
    pub fun now(): UFix64 {
        if StakingRewards.mockTime == true {
            return StakingRewards.mockTimestamp
        } else {
            return getCurrentBlock().timestamp
        }
    }


    init() {
        self.rewardPoolsByID <- {} 
        
        /*
            Setup inital token rewards.
            40 M EmuTokens distributed over 3 years
            tokensPerSecond = 1 and decays by 5.388176% every 28 days .... for ~3 years 3 weeks (40 epochs)
        */
        let emissionDetails = DecayingEmission(
            epochLength: 28.0 * 24.0 * 60.0 * 60.0, 
            totalEpochs: 40.0, 
            decay: 0.05388176
        )

        let liquidityMiningTokens <- self.account.load<@EmuToken.Vault>(from: /storage/liquidityMiningTokens)!

        self.rewardPoolsByID[0] <-! create RewardPool(
            tokens: <- liquidityMiningTokens, 
            emissionDetails: emissionDetails,
            farmWeightsByID: {0: 1.0},
            accessNFTsAccepted: []
        )

        self.nextRewardPoolID = 1
        self.farmsByID <- {}
        
        self.AdminStoragePath = /storage/EmuStakingRewardsAdmin
        self.CollectionStoragePath = /storage/EmuStakingRewardsCollection

        let admin <- create Admin()
        self.account.save(<-admin, to: self.AdminStoragePath)

        self.mockTime = false
        self.mockTimestamp = 0.0
    }
}
