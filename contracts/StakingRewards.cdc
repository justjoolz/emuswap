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
    //
    pub resource RewardPool {
        pub let vault: @FungibleToken.Vault
        pub let farmWeightsByID: {UInt64: UFix64}
        pub(set) var totalWeight: UFix64

        pub let emissionDetails: AnyStruct{EmissionDetails} // used to pass in function for custom emissions rates
        pub(set) var rewardsGenesisTimestamp: UFix64

        pub var accessNFTsAccepted: [String] 

        init(tokens: @FungibleToken.Vault, emissionDetails: {EmissionDetails}, farmWeightsByID: {UInt64: UFix64}, accessNFTsAccepted: [String]) {
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

        // j00lz todo: need to write transactions for these
        pub fun addNFT(nftIdentifier: String) {
            self.accessNFTsAccepted.append(nftIdentifier)
        }

        pub fun removeNFT(index: UInt64) {
            self.accessNFTsAccepted.remove(at: index)
        }

    }

    pub struct Field {
        pub(set) var rewardTokensPerSecond: UFix64              // Tokens allocated per second to stakers in the Farm
        pub(set) var totalAccumulatedTokensPerShare: UFix64     // accJoePerShare 
        init(rewardTokensPerSecond: UFix64, totalAccumulatedTokenPerShare: UFix64) {
            self.rewardTokensPerSecond = rewardTokensPerSecond
            self.totalAccumulatedTokensPerShare = totalAccumulatedTokenPerShare
        }
    } 



    // Farm resource
    //
    // Stored in Farms variable and a reference is never made accessible directly
    //
    pub resource Farm {
        pub let emuSwapPoolID: UInt64
        pub let accessNFTsAccepted: [String]
        pub let stakes: @{Address:Stake}            // Dictionary of Stakes by stakers Address - Stakers get 
        pub let fields: {UInt64: Field}
        pub var lastRewardTimestamp: UFix64                // Last time rewards were calculated
        access(contract) var totalStaked: UFix64

        init(poolID: UInt64) {
            self.stakes <- {}
            self.fields = {}

            log("Populating Fields for each reward pool")
            var i: UInt64 = 0
            while i < UInt64(StakingRewards.rewardPoolsByID.length) {
                log(i)
                let rp = &StakingRewards.rewardPoolsByID[i] as &RewardPool
                log(rp)
                self.fields[i] = Field(rewardTokensPerSecond: rp.emissionDetails.getCurrentEmissionRate(genesisTS: rp.rewardsGenesisTimestamp), totalAccumulatedTokenPerShare: 0.0)
                log(self.fields[i])
                i = i + 1
            }
            log("All fields populated")

            self.totalStaked = 0.0
            self.lastRewardTimestamp = StakingRewards.now()
            self.emuSwapPoolID = poolID
            
            self.accessNFTsAccepted = self.getAllAccessNFTsAccepted()
        }

        destroy () {
            destroy self.stakes
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

        // Update Farm
        //
        // Main internal function that is called every time there is a change to the Farm
        // (tokens staked or unstaked)
        //
        access(contract) fun updateFarm() {
            log("Updating Farm~~~~~~~~~~~~~~~~~~~~")
            let now = StakingRewards.now()
            
            if now <= self.lastRewardTimestamp {    // already up to date
                log("already up to date!")
                log(now)
                self.lastRewardTimestamp = now
                return 
            }

            if self.totalStaked == 0.0 {   // when first stake is being deposited.... nothing staked so nothing paid out
                log("first stake!")
                self.lastRewardTimestamp = now
                return
            }
            
            let period = now - self.lastRewardTimestamp // time delta (aka masterchef 'multiplier')
            log("now")
            log(now)
            log("last reward timestamp")
            log(self.lastRewardTimestamp)
            log("period")
            log(period)

            // we loop through each field of the farm
            // each field in a farm corresponds to a reward pool
            for rewardPoolID in self.fields.keys {
                
                log("rewardPoolID")
                log(rewardPoolID)
                let fieldRef = &self.fields[rewardPoolID] as &Field
                let rewardRef = &StakingRewards.rewardPoolsByID[rewardPoolID] as &RewardPool

                log("field.totalAccumulatedTokensPerShare")
                log(fieldRef.totalAccumulatedTokensPerShare)

                fieldRef.rewardTokensPerSecond = rewardRef.emissionDetails.getCurrentEmissionRate(genesisTS: rewardRef.rewardsGenesisTimestamp) //  
            
                let farmWeight = rewardRef.farmWeightsByID[self.emuSwapPoolID]! / rewardRef.totalWeight  

                let reward = period * fieldRef.rewardTokensPerSecond * farmWeight
                log("reward, self.totalStaked")
                log(reward)
                log(self.totalStaked)
                
                fieldRef.totalAccumulatedTokensPerShare = fieldRef.totalAccumulatedTokensPerShare + (reward / self.totalStaked) // original splits this between dev treasury and farm
                self.lastRewardTimestamp = now
                log("totalAccumulatedTokensPerShare")
                log(fieldRef.totalAccumulatedTokensPerShare)
            }
            log("totalStaked, lastRewardTimestamp")
            log(self.totalStaked)
            log(self.lastRewardTimestamp)
        }

        // Get Pending Rewards Function
        //
        // Gets the total Pending rewards for an address
        // To be called by front end UI and used in metadata
        //

        // j00lz note this doesn't take nfts into account
        pub fun getPendingRewards(address: Address): {UInt64: Fix64} {
            let pendingRewards: {UInt64: Fix64} = {}

            log("get pending rewards")
            log("address: ".concat(address.toString()))
            let now = StakingRewards.now()
            let stakeRef = &self.stakes[address] as &Stake

            for rewardPoolID in self.fields.keys {
                let field = self.fields[rewardPoolID]!
                let rewardRef = &StakingRewards.rewardPoolsByID[rewardPoolID] as &RewardPool
                var totalAccumulatedTokensPerShare = field.totalAccumulatedTokensPerShare
                
                if (now > self.lastRewardTimestamp) && (stakeRef.lpTokenVault.balance > 0.0) {
                    let delta = now - self.lastRewardTimestamp
                    let farmWeight = rewardRef.farmWeightsByID[stakeRef.lpTokenVault.tokenID]! / rewardRef.totalWeight
                    let reward = delta * field.rewardTokensPerSecond * farmWeight
                    totalAccumulatedTokensPerShare = field.totalAccumulatedTokensPerShare  + (reward / self.totalStaked)
                    log("rewardPoolID")
                    log(rewardPoolID)
                    log("delta, farmWeight, reward, totalAccumulatedTokenPerShare, rewardDebt")
                    log(delta)
                    log(farmWeight)
                    log(reward)
                    log(totalAccumulatedTokensPerShare)
                    log(stakeRef.rewardDebtByID[rewardPoolID])
                    log("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
                }
                let pending = Fix64(stakeRef.lpTokenVault.balance * totalAccumulatedTokensPerShare ) - stakeRef.rewardDebtByID[rewardPoolID]!
                pendingRewards.insert(key: rewardPoolID, pending)
            }
            log(pendingRewards)
            return pendingRewards
        }
        
        // Stake function
        //
        // User can deposit their lpTokens and send a receiver Capability that will receive the tokens when withdrawing
        // In return they get a stake controller resource to withdraw to use as reference to withdraw their stake.
        //
        // MasterChef style is to stake 0 lp tokens to trigger payout.... (you claim whenever you add or remove stake)
        pub fun stake(lpTokens: @FungibleTokens.TokenVault, lpTokensReceiverCap: Capability<&{FungibleTokens.CollectionPublic}>, rewardsReceiverCaps: [Capability<&{FungibleToken.Receiver}>], nftReceiverCaps: [Capability<&{NonFungibleToken.CollectionPublic}>], nfts: @[NonFungibleToken.NFT]): @StakeController? {    
            pre {
                // self.accessNFTsAccepted.length == 0 && nfts != nil : "NFT not required for this Farm."
                // self.stakes.containsKey(lpTokensReceiverCap.address) && nft != nil : "NFT already provided!" // need to check for all nfts across rewards pools
                //self.accessNFTsAccepted.length > 0 
                //    && !self.accessNFTsAccepted.contains(nft.getType().identifier) : "NFT provided is not of required type for this farm!"
            }
            log("Stake")
            self.updateFarm()
            log("farm updated")
            
            // special case first ever stake sets genesis reward timestamp of first ever reward pool
            // j00lz not sure if this is needed/correct
            if self.stakes.length == 0 {
                log("NO STAKES!")
                let field = self.fields[0]!
                let rewardRef = &StakingRewards.rewardPoolsByID[0] as &RewardPool
                rewardRef.rewardsGenesisTimestamp = self.lastRewardTimestamp
            }
            
            // Get LP Token ID
            let id = lpTokens.tokenID
            // Get amount of tokens to add to stake
            let amountStaked = lpTokens.balance
            // Get reference to users stake

            log(self.totalStaked)

            // Update users stake 
            if !self.stakes.containsKey(lpTokensReceiverCap.address) { // New Stake

                log("Total Staked:")
                log(amountStaked)

                let rewardDebtByID: {UInt64: Fix64} = {}

                // calculate reward debts for each field/reward pool
                for poolID in StakingRewards.rewardPoolsByID.keys {
                    if self.fields.containsKey(poolID) { // if this farm has a field matching the reward pool - failsafe, possibly unrequired as all farms should always be updated on creation of new RewardPools or Farm  
                        log("matching farm found for poolID")
                        log(poolID)
                        
                        let field = self.fields[poolID]!
                        let rewardPoolRef = &StakingRewards.rewardPoolsByID[poolID] as &RewardPool
                        
                        log("number of nfts accepted for this pool")
                        log(rewardPoolRef.accessNFTsAccepted.length)
                        
                        if rewardPoolRef.accessNFTsAccepted.length == 0 || rewardPoolRef.acceptsNFTs(&nfts as &[NonFungibleToken.NFT]) { // if no nft required or accepted nft deposited    
                            let rewardDebt = Fix64(amountStaked * field.totalAccumulatedTokensPerShare)
                            log("reward debt updated")
                            rewardDebtByID[poolID] = rewardDebt
                            log(rewardDebt)
                        } else {
                            log("no accepted nft provided")
                        }

                        
                    } else {
                        log("not matching farm found for ID:")
                        log(poolID)

                    }
                }
                log("among pool IDs")
                log(self.fields)
                log("rewardDebtByID")
                log(rewardDebtByID)
            
                let newStake <- create Stake(lpTokens: <- lpTokens, rewardDebt: rewardDebtByID, lpTokenReceiverCap: lpTokensReceiverCap, rewardsReceiverCaps: rewardsReceiverCaps, nfts: <- nfts, nftReceiverCaps: nftReceiverCaps)
                
                // Insert into the Farms stakes field
                self.stakes[lpTokensReceiverCap.address] <-! newStake

                // update Farm total staked
                self.totalStaked = self.totalStaked + amountStaked

                emit TokensStaked(address: lpTokensReceiverCap.address, amountStaked: amountStaked, totalStaked: self.totalStaked)

                // return stake controller for user to access their funds
                // possibly unrequired.... as lpTokenReceiver is provided on inialization... worst anyone can do is call and send the user their rewards?! 
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
                log("REWARD DEBT!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
                log(stakeRef.rewardDebtByID)     

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
                stakeControllerRef.lpTokenReceiverCap.check() : "invalid token receiver cap?!"
            }

            let address = stakeControllerRef.lpTokenReceiverCap.address 
            assert( amount <= self.stakes[address]?.lpTokenVault?.balance!, message: "Insufficient LP Tokens available to withdraw. ".concat(
                amount.toString()).concat(" ").concat( 
                    (self.stakes[address]?.lpTokenVault?.balance!).toString()))

            // get reference to stake
            let stakeRef = stakeControllerRef.borrowStake() // &self.stakes[stakeControllerRef.lpTokenReceiverCap.address] as &Stake
            
            // if withdrawing everything return their nfts
            if stakeRef.lpTokenVault.balance == 0.0 {
                for nftIdentifier in self.accessNFTsAccepted {
                    let nftReceiver = stakeRef.nftReceiverCapsByID[nftIdentifier]!.borrow()
                    nftReceiver?.deposit(token: <- stakeRef.withdrawNFT(identifier: nftIdentifier)!)
                }
            }
            
            // Withdraw requested amount of LP Tokens and return to the user
            let receiverRef = stakeControllerRef.lpTokenReceiverCap.borrow()
            
            // payout rewards
            for poolID in StakingRewards.rewardPoolsByID.keys {
                let field = self.fields[poolID]!
            
                log("MATH~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
                log(stakeRef.rewardDebtByID[poolID])
                log(amount * field.totalAccumulatedTokensPerShare)
                
                let rewardPoolRef = &StakingRewards.rewardPoolsByID[poolID] as &RewardPool
                if rewardPoolRef.acceptsNFTsByKeys(stakeRef.getNFTIdentifiers()) {
                    stakeRef.rewardDebtByID[poolID] = stakeRef.rewardDebtByID[poolID]! - Fix64(amount * field.totalAccumulatedTokensPerShare)
                }
            }
                
            let tokens <- stakeRef.lpTokenVault.withdraw(amount: amount)
            receiverRef?.deposit!(from: <- tokens)

            // update Farm total
            self.totalStaked = self.totalStaked - amount

            self.updateFarm()

            ///// j00lz 2 do check if the update farm needs to go above the depositing above.... possibly balance changes?
            // this code returns all pending rewards on unstaking..... 
            /*
            let pending = (stakeRef.lpTokenVault.balance * self.totalAccumulatedTokensPerShare) - stakeRef.rewardDebt 

            // distribute pending 
            let rewards <- StakingRewards.vault.withdraw(amount: pending)
            let rewardsReceiverRef = stakeControllerRef.rewardsReceiverCap.borrow()!
            rewardsReceiverRef.deposit(from: <- rewards)
             */
        }


        // Claim Rewards
        // j00lz todo needs optimizing (repeated call of getPendingRewards)
        // can consider refactoring these 2 functions into the stake resource....
        pub fun claimRewards(stakeControllerRef: &StakeController) {
            self.updateFarm()
            let stakeRef = stakeControllerRef.borrowStake()
            
            // j00lz swapped this line for the working getPendingRewards function..... otherwise self.totalAccumulatedTokensPerShare is always 0 ???????  
            // let pending = stakeRef.lpTokenVault.balance * self.totalAccumulatedTokensPerShare - stakeRef.rewardDebt
            
            log("Claiming rewards")
            log(stakeControllerRef)

            for poolID in StakingRewards.rewardPoolsByID.keys {
                log("Pool")
                log(poolID)

                if self.fields.containsKey(poolID) { // j00lz if this farm has a field matching the reward pool.... failsafe possibly unrequired as should fields should always be updated on farm and reward pool creation.

                    let field = self.fields[poolID]!
                    
                    let accumulatedTokens = stakeRef.lpTokenVault.balance * field.totalAccumulatedTokensPerShare
                    let pending = Fix64(accumulatedTokens) - stakeRef.rewardDebtByID[poolID]!

                    log("accumulatedTokens")
                    log(accumulatedTokens)
                    log("pending")
                    log(pending)

                    //let pending = stakeRef.lpTokenVault.balance * self.totalAccumulatedTokensPerShare - stakeRef.rewardDebt
                    // let pending = self.getPendingRewards(address: stakeRef.rewardsReceiverCap.address)

                    if stakeRef.rewardsReceiverCaps[poolID] != nil { // user has provided the correct receiver already... if there is a new reward pool added the user will need to setup and provide a new matching receiver to claim 
                        // update reward debt
                        stakeRef.rewardDebtByID[poolID] = Fix64(accumulatedTokens)
                         // distribute pending
                        let rewards <- StakingRewards.rewardPoolsByID[poolID]?.vault?.withdraw(amount: UFix64(pending))!

                        log("REWARDS TYPE")
                        log(rewards.getType().identifier)
                        let rewardTokenType = rewards.getType().identifier

                        log("corresponding Stake ref type" )
                        log(stakeRef.rewardsReceiverCaps[poolID])
                        log(stakeRef.rewardsReceiverCaps[poolID].getType())
                        // let tokenType = stakeRef.rewardsReceiverCaps[poolID]?.borrow().getType().identifier
                        
                        log("DEPOSITING!")
                        stakeRef.rewardsReceiverCaps[poolID]?.borrow()!!.deposit(from: <-rewards)
                        log(
                            "user: ".concat(
                                stakeRef.rewardsReceiverCaps[poolID]!.address.toString().concat(
                                    " claimed: ".concat(
                                        pending.toString().concat(
                                            " rewardDebt:".concat(
                                                stakeRef.rewardDebtByID[poolID]!.toString()
                                            )
                                        )
                                    )
                                )
                            )
                        )
                        emit RewardsClaimed(address: stakeRef.rewardsReceiverCaps[0]!.address, tokenType: rewardTokenType, amountClaimed: UFix64(pending), rewardDebt: stakeRef.rewardDebtByID[poolID]!, totalRemaining: StakingRewards.rewardPoolsByID[poolID]?.vault?.balance!)
                    } else {
                        log("NO RECEIVER FOR REWARD!")
                        log(StakingRewards.rewardPoolsByID[poolID]?.vault?.getType())
                        log("USER NEEDS a ..... to withdraw these rewards.... ")
                        log("NOT DEPOSITING!")
                        log("Need to alert user in front end if they have correct receivers for all available rewards")
                    }

                }
            }
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
        //pub var rewards: @FungibleToken.Vault
        access(contract) var lpTokenReceiverCap: Capability<&{FungibleTokens.CollectionPublic}>
        access(contract) var rewardsReceiverCaps: {UInt64: Capability<&{FungibleToken.Receiver}>}
        

        init(lpTokens: @FungibleTokens.TokenVault, rewardDebt: {UInt64: Fix64}, lpTokenReceiverCap: Capability<&{FungibleTokens.CollectionPublic}>, rewardsReceiverCaps: [Capability<&{FungibleToken.Receiver}>], nfts: @[NonFungibleToken.NFT], nftReceiverCaps: [Capability<&{NonFungibleToken.CollectionPublic}>]) {
            self.lpTokenVault <- lpTokens
            self.lpTokenReceiverCap = lpTokenReceiverCap

            self.rewardsReceiverCaps = {}
            // insert rewardReceivers 
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
            let nullResource <- 
                self.ownedStakeControllers.insert(key: stakeController.farmID, <-stakeController)
            destroy nullResource
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
    // only admin can create farms and update pool weights
    pub resource Admin {


        // Create Rewards Pool
        //
        //
        //
        pub fun createRewardPool(tokens: @FungibleToken.Vault, emissionDetails: AnyStruct{EmissionDetails}, farmWeightsByID: {UInt64: UFix64}, accessNFTsAccepted: [String]) {
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
                let rp = &StakingRewards.rewardPoolsByID[id] as &RewardPool
                log(id)
                log(farmRef)
                log(farmRef.fields)
                farmRef.fields[poolID] = Field(rewardTokensPerSecond: rp.emissionDetails.getCurrentEmissionRate(genesisTS: rp.rewardsGenesisTimestamp), totalAccumulatedTokenPerShare: 0.0)

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

    
    //
    // We do some fancy math here. Basically, any point in time, the amount of Emu Tokens
    // entitled to a user but is pending to be distributed is:
    //
    //   pending reward = (user.amount * Farm.accEmuPerShare) - user.rewardDebt
    //
    // Whenever a user deposits or withdraws LP tokens to a Farm. Here's what happens:
    //   1. The Farm's `accEmuPerShare` (and `lastRewardTimestamp`) gets updated.
    //   2. User receives the pending reward sent to his/her address.
    //   3. User's `amount` gets updated.
    //   4. User's `rewardDebt` gets updated.
    //
    // https://github.com/pancakeswap/pancake-farm/blob/master/contracts/MasterChef.sol

     // Info of each Farm.
    pub struct FarmInfo {
        pub let id: UInt64;                // ID of LP token.
        pub let totalStaked: UFix64
        pub let stakes: {Address: StakeInfo}
        pub let lastRewardTimestamp: UFix64 // Last timestamp that EmuToken distribution occured
        pub let allocPointByID: {UInt64: UFix64};         // How many allocation points assigned to this Farm. EmuTokens to distribute per second.
        pub let rewardTokensPerSecondByID: {UInt64: UFix64} 
        pub let totalAccumulatedTokensPerShareByID: {UInt64: UFix64}      // Accumulated EmuTokens per share, times 1e12. See below.
        init(_ farmRef: &Farm) {
            self.id = farmRef.emuSwapPoolID
            self.totalStaked = farmRef.totalStaked
            self.stakes = farmRef.readStakes()
            self.lastRewardTimestamp = farmRef.lastRewardTimestamp
            
            self.allocPointByID = {}
            self.rewardTokensPerSecondByID = {}
            self.totalAccumulatedTokensPerShareByID = {}

            for poolID in StakingRewards.rewardPoolsByID.keys {
                let fieldRef = &farmRef.fields[poolID] as &Field
                let rewardPoolRef = &StakingRewards.rewardPoolsByID[poolID] as &RewardPool
                self.allocPointByID[poolID] = rewardPoolRef.farmWeightsByID[self.id]!
                self.rewardTokensPerSecondByID[poolID] = fieldRef.rewardTokensPerSecond
                self.totalAccumulatedTokensPerShareByID[poolID] = fieldRef.totalAccumulatedTokensPerShare
            }
        }        
    }

    pub fun createStakingControllerCollection(): @StakeControllerCollection {
        return <- create StakeControllerCollection()
    }

    pub fun getFarmInfo(id: UInt64): FarmInfo? {
        let farmRef = &StakingRewards.farmsByID[id] as &Farm
        if farmRef != nil {
            return FarmInfo(farmRef)
        }
        return nil
    }

    pub fun borrowFarm(id: UInt64): &Farm? {
        //return &self.farmsByID[id] as &Farm
        if self.farmsByID.keys.contains(id) {
            return &self.farmsByID[id] as &Farm
        } 
        return nil
    }

    // currently unused
    access(contract) fun updateFarms() {
        for key in self.farmsByID.keys {
            self.farmsByID[key]?.updateFarm()
        }
    }
   
    /*

        40 M tokens over 3 years
        
        tokensPerSecond = 1
        reduced by 5.964249 % every 31 days..... for 3 years 3 weeks 
                   5.388176 % every 28 days .... for 3 years 3 weeks  
    */

    // getCurrentEmissionRate function
    //
    // this is called on every updateFarm()
    // 

    // A function that returns an emission rate relative to a given genesis timestamp
    pub struct interface EmissionDetails {
        pub fun getCurrentEmissionRate(genesisTS: UFix64): UFix64
    } 

    // General purpose structure to return a decaying rate over time
    //
    pub struct DecayingEmission: EmissionDetails {
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
        
        let liquidityMiningTokens <- self.account.load<@EmuToken.Vault>(from: /storage/liquidityMiningTokens)!
        self.rewardPoolsByID[0] <-! create RewardPool(
            tokens: <- liquidityMiningTokens, 
            emissionDetails: DecayingEmission(              // Any struct can be passed in that 
                epochLength: 28.0 * 24.0 * 60.0 * 60.0, 
                totalEpochs: 40.0, 
                decay: 0.05388176
            ), 
            farmWeightsByID: {0: 1.0},
            accessNFTsAccepted: []
        )

        self.nextRewardPoolID = 1 // 1 as we add the default emu distribution here on contract deploy at the moment
        self.farmsByID <- {}
        
        self.AdminStoragePath = /storage/EmuStakingRewardsAdmin
        self.CollectionStoragePath = /storage/EmuStakingRewardsCollection

        let admin <- create Admin()
        self.account.save(<-admin, to: self.AdminStoragePath)

        self.mockTime = false
        self.mockTimestamp = 0.0
    }
}
