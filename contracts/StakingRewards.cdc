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

pub contract StakingRewards {
    pub let PRECISION: UFix64

    // Main Vault with all Emu reward tokens
    // j00lz can maybe wrap these as emissions incentivzor or  something so can use other tokens later :)
    access(contract) let vault: @FungibleToken.Vault        // master rewards vault divvied between pools according to farmWeights
    access(contract) let masterRewardVaultByIdentifier: @{String: FungibleToken.Vault}        // master rewards vault divvied between pools according to farmWeights
    access(contract) var rewardsGenesisTimestamp: UFix64

    // Dictionary of Farms by EmuSwap.Farm.ID
    access(contract) let farmsByID: @{UInt64:Farm}          // Farm Resource indexed by the ID of their EmuSwap pool 
    access(contract) let farmWeightsByID: {UInt64: UFix64}  // Farm weights are used to share the rewards per Farm.....
    access(contract) var totalWeight : UFix64               // Total Weight  (totalAllocPoint)

    // Paths
    pub let AdminStoragePath: StoragePath
    pub let CollectionStoragePath: StoragePath

    // Events
    pub event NewFarmCreated(farmID: UInt64, weight: UFix64, totalWeight: UFix64)
    pub event EmissionRateUpdated(newRate: UFix64)          // j00lz todo needs to have poolID too
    pub event TokensStaked(address: Address, amountStaked: UFix64, totalStaked: UFix64)
    pub event TokensUnstaked(address: Address, amountUnstaked: UFix64, totalStaked: UFix64)
    pub event RewardsClaimed(address: Address, amountClaimed: UFix64, rewardDebt: Fix64, totalRemaining: UFix64)

    // Testing Mock time
    access(contract) var mockTime: Bool
    access(contract) var mockTimestamp: UFix64

    // Farm resource
    //
    // Stored in Farms variable and a reference is never made accessible directly
    //
    pub resource Farm {
        pub let emuSwapPoolID: UInt64
        pub let stakes: @{Address:Stake}            // Dictionary of Stakes by stakers Address - Stakers get 

        access(contract) var totalStaked: UFix64
        access(contract) var rewardTokensPerSecond: UFix64              // Tokens allocated per second to stakers in the Farm
        access(contract) var lastRewardTimestamp: UFix64                // Last time rewards were calculated
        access(contract) var totalAccumulatedTokensPerShare: UFix64     // accJoePerShare 
    
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
            log("totalAccumulatedTokensPerShare, lastRewardTimestamp")
            log(self.totalAccumulatedTokensPerShare)
            log(self.lastRewardTimestamp)


            self.rewardTokensPerSecond = StakingRewards.getCurrentEmissionRate() 
            let now = StakingRewards.now()

            log("now")
            log(now)

            if now <= self.lastRewardTimestamp {    // already up to date
                self.lastRewardTimestamp = now
                return 
            }

            if self.totalStaked == 0.0 {   // when first stake is being deposited.... nothing staked so nothing paid out
                self.lastRewardTimestamp = now
                return
            }

            let period = now - self.lastRewardTimestamp // time delta (aka masterchef 'multiplier')
            log("period")
            log(period)
            
            let farmWeight = StakingRewards.farmWeightsByID[self.emuSwapPoolID]! / StakingRewards.totalWeight 
            
            let reward = period * self.rewardTokensPerSecond * farmWeight
            log("reward, self.totalStaked")
            log(reward)
            log(self.totalStaked)

            self.totalAccumulatedTokensPerShare = self.totalAccumulatedTokensPerShare + (reward * StakingRewards.PRECISION / self.totalStaked) // original splits this between dev treasury and farm
            self.lastRewardTimestamp = now
            log("totalAccumulatedTokensPerShare, lastRewardTimestamp")
            log(self.totalAccumulatedTokensPerShare)
            log(self.lastRewardTimestamp)
        }

        // Get Pending Rewards Function
        //
        // Gets the total Pending rewards for an address
        // To be called by front end UI and used in metadata
        //
        pub fun getPendingRewards(address: Address): Fix64 {
            log("get pending rewards")
            log("address: ".concat(address.toString()))
            let now = StakingRewards.now()
            let stakeRef = &self.stakes[address] as &Stake

            var totalAccumulatedTokensPerShare = self.totalAccumulatedTokensPerShare
            
            if (now > self.lastRewardTimestamp) && (stakeRef.lpTokenVault.balance > 0.0) {
                let delta = now - self.lastRewardTimestamp
                let farmWeight = StakingRewards.farmWeightsByID[stakeRef.lpTokenVault.tokenID]! / StakingRewards.totalWeight
                let reward = delta * self.rewardTokensPerSecond * farmWeight
                totalAccumulatedTokensPerShare = self.totalAccumulatedTokensPerShare  + (reward * StakingRewards.PRECISION / self.totalStaked)
                log("delta, farmWeight, reward, totalAccumulatedTokenPerShare, rewardDebt, pending")
                log(delta)
                log(farmWeight)
                log(reward)
                log(totalAccumulatedTokensPerShare)
                log(stakeRef.rewardDebt)
            }
            let pending = Fix64(stakeRef.lpTokenVault.balance * totalAccumulatedTokensPerShare / StakingRewards.PRECISION ) - stakeRef.rewardDebt
            log(pending)

            return pending 
        }
        
        // Stake function
        //
        // User can deposit their lpTokens and send a receiver Capability that will receive the tokens when withdrawing
        // In return they get a stake controller resource to withdraw to use as reference to withdraw their stake.
        //
        // MasterChef style is to stake 0 lp tokens to trigger payout.... (you claim whenever you add or remove stake)
        pub fun stake(lpTokens: @FungibleTokens.TokenVault, lpTokensReceiverCap: Capability<&{FungibleTokens.CollectionPublic}>, rewardsReceiverCap: Capability<&{FungibleToken.Receiver}>): @StakeController? {    
            log("Stake")
            self.updateFarm()
            log("farm updated")
            
            if self.stakes.length == 0 {
                StakingRewards.rewardsGenesisTimestamp = self.lastRewardTimestamp
            }

            // Get LP Token ID
            let id = lpTokens.tokenID
            // Get amount of tokens to add to stake
            let amountStaked = lpTokens.balance
            // Get reference to users stake
            
            log("totalStaked, totalAccumulatedTokensPerShare  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" )
            log(self.totalStaked)
            log(self.totalAccumulatedTokensPerShare)

            // Update users stake 
            if !self.stakes.containsKey(lpTokensReceiverCap.address) { // New Stake

                log("YO!")
                log(amountStaked)
                log(self.totalAccumulatedTokensPerShare)
                let rewardDebt = Fix64(amountStaked * self.totalAccumulatedTokensPerShare / StakingRewards.PRECISION)
            
                let newStake <- create Stake(lpTokens: <- lpTokens, rewardDebt: rewardDebt, lpTokenReceiverCap: lpTokensReceiverCap, rewardsReceiverCap: rewardsReceiverCap)
                
                log("REWARD DEBT!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
                log(newStake.rewardDebt)

                // Insert into the Farms stakes field
                let temp 
                    <- self.stakes.insert(key: lpTokensReceiverCap.address, <- newStake)
                destroy temp
                // update Farm total staked
                self.totalStaked = self.totalStaked + amountStaked

                

                emit TokensStaked(address: lpTokensReceiverCap.address, amountStaked: amountStaked, totalStaked: self.totalStaked)

                // return stake controller for user to access their funds
                // possibly unrequired.... as lpTokenReceiver is provided on inialization... worst anyone can do is call and send the user their rewards?! 
                return <- create StakeController(id: id, lpTokenReceiverCap: lpTokensReceiverCap, rewardsReceiverCap: rewardsReceiverCap) // id needs to be unique per user and per Farm
            } 
            else {
                let stakeRef = &self.stakes[lpTokensReceiverCap.address] as &Stake        
                // add to existing stake
                stakeRef.lpTokenVault.deposit(from: <-lpTokens)
                
                // update Farm total
                self.totalStaked = self.totalStaked + amountStaked
                
                stakeRef.setRewardDebt( stakeRef.rewardDebt + Fix64(amountStaked * self.totalAccumulatedTokensPerShare / StakingRewards.PRECISION))  
                log("REWARD DEBT!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
                log(stakeRef.rewardDebt)            

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

            // Withdraw requested amount of LP Tokens and return to the user
            let receiverRef = stakeControllerRef.lpTokenReceiverCap.borrow()
            let stakeRef = &self.stakes[stakeControllerRef.lpTokenReceiverCap.address] as &Stake
            
            log("MATH~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
            log(stakeRef.rewardDebt)
            log(amount * self.totalAccumulatedTokensPerShare)
            stakeRef.setRewardDebt( stakeRef.rewardDebt - Fix64(amount * self.totalAccumulatedTokensPerShare / StakingRewards.PRECISION))
            
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
            
            let accumulatedTokens = stakeRef.lpTokenVault.balance * self.totalAccumulatedTokensPerShare
            let pending = Fix64(accumulatedTokens) - stakeRef.rewardDebt

            //let pending = stakeRef.lpTokenVault.balance * self.totalAccumulatedTokensPerShare - stakeRef.rewardDebt
            // let pending = self.getPendingRewards(address: stakeRef.rewardsReceiverCap.address)

            // update reward debt
            stakeRef.setRewardDebt(Fix64(accumulatedTokens))

            // distribute pending
            let rewards <- StakingRewards.vault.withdraw(amount: UFix64(pending))
            stakeRef.rewardsReceiverCap.borrow()!.deposit(from: <-rewards)
            log(
                "user: ".concat(
                    stakeRef.rewardsReceiverCap.address.toString().concat(
                        " claimed: ".concat(
                            pending.toString().concat(
                                " rewardDebt:".concat(
                                    stakeRef.rewardDebt.toString()
                                )
                            )
                        )
                    )
                )
            )
            emit RewardsClaimed(address: stakeRef.rewardsReceiverCap.address, amountClaimed: UFix64(pending), rewardDebt: stakeRef.rewardDebt, totalRemaining: StakingRewards.vault.balance)
        }    



        init(poolID: UInt64) {
            self.stakes <- {}
            self.totalStaked = 0.0
            self.rewardTokensPerSecond = StakingRewards.getCurrentEmissionRate()
            self.lastRewardTimestamp = StakingRewards.now()
            self.totalAccumulatedTokensPerShare = 0.0
            self.emuSwapPoolID =poolID
        }

        destroy () {
            destroy self.stakes
        }
    }

    // Stake Resource
    //
    // Holds the staked funds of the user. (lp)
    // A receiver Caabiity to return their funds
    // total reward debt calculated 
    // 
    pub resource Stake {

        pub var lpTokenVault: @FungibleTokens.TokenVault
        //pub var rewards: @FungibleToken.Vault
        pub var lpTokenReceiverCap: Capability<&{FungibleTokens.CollectionPublic}>
        pub var rewardsReceiverCap: Capability<&{FungibleToken.Receiver}>
        pub var rewardDebt: Fix64 // aka reward debt

        init(lpTokens: @FungibleTokens.TokenVault, rewardDebt: Fix64, lpTokenReceiverCap: Capability<&{FungibleTokens.CollectionPublic}>, rewardsReceiverCap: Capability<&{FungibleToken.Receiver}>) {
            self.lpTokenVault <- lpTokens
            self.lpTokenReceiverCap = lpTokenReceiverCap
            self.rewardsReceiverCap = rewardsReceiverCap
            self.rewardDebt = rewardDebt
        }

        access(contract) fun setRewardDebt(_ debt: Fix64) {
            self.rewardDebt = debt 
        }

        destroy () {
            destroy self.lpTokenVault
        }
    }


    pub struct StakeInfo {
        pub let address: Address
        pub let balance: UFix64
        pub let rewardDebt: Fix64
        pub let pendingRewards: Fix64 
        init(_ stake: &Stake, farm: &Farm) {
            self.address = stake.lpTokenReceiverCap.address
            self.balance = stake.lpTokenVault.balance
            self.rewardDebt = stake.rewardDebt
            self.pendingRewards = farm.getPendingRewards(address: self.address)
        }
    }



    // Stake Controller Resource
    //
    // User's reference to their stake.
    //
    pub resource StakeController {
        pub let farmID: UInt64

        pub var nftBooster: @NonFungibleToken.NFT?
        
        pub let lpTokenReceiverCap: Capability<&{FungibleTokens.CollectionPublic}>
        pub let rewardsReceiverCap: Capability<&{FungibleToken.Receiver}>

        pub fun borrowStake(): &Stake {
            let farmRef = StakingRewards.borrowFarm(id: self.farmID)!
            let stakeRef = &farmRef.stakes[self.lpTokenReceiverCap.address] as &Stake
            return stakeRef
        }

        init(id: UInt64, lpTokenReceiverCap: Capability<&{FungibleTokens.CollectionPublic}>, rewardsReceiverCap: Capability<&{FungibleToken.Receiver}>) {
            self.farmID = id
            self.lpTokenReceiverCap = lpTokenReceiverCap
            self.rewardsReceiverCap = rewardsReceiverCap
            self.nftBooster <- nil
        }

        // could trigger unstake from resource in users wallet....
        pub fun unstake() {

        }

        pub fun claimRewards() {

        }

        pub fun depositNFT(nft: @NonFungibleToken.NFT) {
            pre {
                // nft.isInstance(<EmuNFT.NFT>)
            }
            self.nftBooster <-! nft
        }

        destroy() {
            destroy self.nftBooster
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
        pub fun createFarm(poolID: UInt64, weight: UFix64) {
            pre {
                weight > 0.0 : "Farm weight must be positive"
                EmuSwap.getPoolIDs().contains(poolID) : "Pool does not exist on EmuSwap!"
            }
            let newFarm <- create Farm(poolID: poolID)
            let nullResource <- 
                StakingRewards.farmsByID.insert(key: poolID, <- newFarm)
            destroy nullResource
            StakingRewards.farmWeightsByID.insert(key: poolID, weight)
            StakingRewards.totalWeight = StakingRewards.totalWeight + weight 
            
            log( StakingRewards.getFarmInfo(id: poolID) )
            emit NewFarmCreated(farmID: poolID, weight: weight, totalWeight: StakingRewards.totalWeight)
        }

        pub fun updateFarmWeight(farmID: UInt64, newWeight: UFix64) {
            let oldWeight = StakingRewards.farmWeightsByID[farmID]!
            StakingRewards.farmWeightsByID[farmID] = newWeight
            StakingRewards.totalWeight = StakingRewards.totalWeight - oldWeight + newWeight
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
        pub let allocPoint: UFix64;         // How many allocation points assigned to this Farm. EmuTokens to distribute per second.
        pub let lastRewardTimestamp: UFix64 // Last timestamp that EmuToken distribution occured
        pub let rewardTokensPerSecond: UFix64 
        pub let totalAccumulatedTokensPerShare: UFix64      // Accumulated EmuTokens per share, times 1e12. See below.
        init(_ farmRef: &Farm) {
            self.id = farmRef.emuSwapPoolID
            self.totalStaked = farmRef.totalStaked
            self.stakes = farmRef.readStakes()
            self.allocPoint = StakingRewards.farmWeightsByID[self.id]!
            self.lastRewardTimestamp = farmRef.lastRewardTimestamp
            self.rewardTokensPerSecond = farmRef.rewardTokensPerSecond
            self.totalAccumulatedTokensPerShare = farmRef.totalAccumulatedTokensPerShare
        }        
    }

    pub fun createStakingControllerCollection(): @StakeControllerCollection {
        return <- create StakeControllerCollection()
    }

    pub fun getFarmInfo(id: UInt64): FarmInfo {
        let farmRef = &self.farmsByID[id] as &Farm
        return FarmInfo(farmRef)
    }

    pub fun borrowFarm(id: UInt64): &Farm? {
        //return &self.farmsByID[id] as &Farm
        if self.farmsByID.keys.contains(id) {
            return &self.farmsByID[id] as &Farm
        } else {
            return nil
        }
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
    // j00lz todo: can calculate these epochs in advance and store in a table to reduce computation
    // 
    pub fun getCurrentEmissionRate(): UFix64 {
        /*
        if StakingRewards.rewardsGenesisTimestamp == 0.0 {
            return 0.0
        }
         */
        let epochLength = 28.0 * 24.0 * 60.0 * 60.0 
        let decay = 0.05388176 // for 31days use: 0.05964249
        
        // if first 
        // let genesisTimestamp = StakingRewards.rewardsGenesisTimestamp
        let genesisTimestamp = StakingRewards.rewardsGenesisTimestamp == 0.0 ? StakingRewards.now() : StakingRewards.rewardsGenesisTimestamp

        let now = StakingRewards.now()
        
        let elapsedTime = now - genesisTimestamp
        
        var currentEpoch = elapsedTime / epochLength

        if currentEpoch > 40.0 {
            return 1.0
        }

        var rate = 1.0
        while currentEpoch > 1.0 {
            rate = rate * (1.0-decay)
            currentEpoch = currentEpoch - 1.0
        }

        return rate
    }

    // getCurrentEpoch 
    //
    // returns current epoch (not rounded)
    //
    pub fun getCurrentEpoch(): UFix64 {
        let epochLength = 28.0 * 24.0 * 60.0 * 60.0 
        let now = StakingRewards.now()        
        let genesisTimestamp = StakingRewards.rewardsGenesisTimestamp == 0.0 ? now : StakingRewards.rewardsGenesisTimestamp
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
        self.PRECISION = 1.0 // 0.00000001
        self.vault <- self.account.load<@EmuToken.Vault>(from: /storage/liquidityMiningTokens)!
        self.masterRewardVaultByIdentifier <- {} // currently unused... to allow farms to distribute different tokens in the future
        self.rewardsGenesisTimestamp = 0.0
        self.farmsByID <- {}
        self.farmWeightsByID = {}
        self.totalWeight = 0.0
        
        self.AdminStoragePath = /storage/EmuStakingRewardsAdmin
        self.CollectionStoragePath = /storage/EmuStakingRewardsCollection

        let admin <- create Admin()
        self.account.save(<-admin, to: self.AdminStoragePath)

        self.mockTime = false
        self.mockTimestamp = 0.0
    }
}
