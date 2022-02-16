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
// https://hackernoon.com/implementing-staking-in-solidity-1687302a82cf
// https://ethereum.stackexchange.com/questions/99106/unable-to-understand-master-chef-contract-in-pancake-swap
//

pub contract StakingRewards {

    // Main Vault with all Emu reward tokens
    // j00lz can maybe wrap these as emissions incentivzor or  something so can use other tokens later :)
    access(contract) let vault: @FungibleToken.Vault
    access(contract) var rewardsGenesisTimestamp: UFix64

    // Dictionary of Farms by EmuSwap.Farm.ID
    access(contract) let farmsByID: @{UInt64:Farm}          // Farm Resource indexed by the ID of their EmuSwap pool 
    access(contract) let farmWeightsByID: {UInt64: UFix64}  // Farm weights are used to share the rewards per Farm.....
    access(contract) let totalWeight : UFix64               // Total Weight  (totalAllocPoint)

    // Events
    pub event EmissionRateUpdated(newRate: UFix64)          // j00lz todo needs to have poolID too 

    // Farm resource
    //
    // Stored in Farms variable and a reference is never made accessible directly
    //
    pub resource Farm {
        access(contract) var emuSwapPoolID: UInt64

        pub let stakes: @{Address:Stake}            // Dictionary of Stakes by stakers Address - Stakers get 
        access(contract) var totalStaked: UFix64
        
        access(contract) var rewardTokensPerSecond: UFix64              // Tokens allocated per second to stakers in the Farm
        access(contract) var lastRewardTimestamp: UFix64                // Last time rewards were calculated
        access(contract) var totalAccumulatedTokensPerShare: UFix64     // allocPoint 

        /*
            // Get Total Staked
            // 
            // Returns the total amount of tokens staked at any given moment
            // *unrequired* optimized by keeping totalStaked field on Farm up to date 
            //
            pub fun getTotalStaked(): UFix64 {
                let keys = self.stakes.keys
                let total = 0.0
                for key in keys {
                    let stakeRef = &self.stakes[key] as Stake
                    total = total + stakeRef.vault.balance
                }
                return total
            }
         */
        
        // Stake function
        //
        // User can deposit their lpTokens and send a receiver Capability that will receive the tokens when withdrawing
        // In return they get a stake controller resource to withdraw to use as reference to withdraw their stake.
        //
        // MasterChef style is to stake 0 lp tokens to trigger payout.... (you claim whenever you add or remove stake)
        pub fun stake(lpTokens: @FungibleTokens.TokenVault, lpTokensReceiverCap: Capability<&{FungibleTokens.Receiver}>, rewardsReceiverCap: Capability<&{FungibleToken.Receiver}>): @StakeController? {    
            self.updateFarm()

            let firstStake = false
            if firstStake {
                StakingRewards.rewardsGenesisTimestamp = getCurrentBlock().timestamp
            }

            // Get LP Token ID
            let id = lpTokens.tokenID
            // Get amount of tokens to add to stake
            let amountStaked = lpTokens.balance
            // Get reference to users stake
            let stakeRef = &self.stakes[lpTokensReceiverCap.address] as &Stake
            
            // Update users stake 
            if stakeRef == nil { // New Stake 
                // Insert into the Farms stakes field
                let temp 
                    <- self.stakes.insert(key: lpTokensReceiverCap.address, <- create Stake(lpTokens: <- lpTokens, lpTokenReceiverCap: lpTokensReceiverCap, rewardsReceiverCap: rewardsReceiverCap))
                destroy temp

                // update Farm total
                self.totalStaked = self.totalStaked + amountStaked

                // return stake controller for user to access their funds 
                return <- create StakeController(id: id, lpTokenReceiverCap: lpTokensReceiverCap, rewardsReceiverCap: rewardsReceiverCap) // id needs to be unique per user and per Farm
            } else {
                // add to existing stake
                stakeRef.lpTokenVault.deposit(from: <-lpTokens)
                
                // update Farm total
                self.totalStaked = self.totalStaked + amountStaked
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
            }

            let address = stakeControllerRef.lpTokenReceiverCap.address 
            assert( amount > self.stakes[address]?.lpTokenVault?.balance!, message: "Insufficient LP Tokens available to withdraw.")

            // Withdraw requested amount of LP Tokens and return to the user
            let receiverRef = stakeControllerRef.lpTokenReceiverCap.borrow()
            let stakeRef = &self.stakes[stakeControllerRef.lpTokenReceiverCap.address] as &Stake
            let tokens <- stakeRef.lpTokenVault.withdraw(amount: amount)
            receiverRef?.deposit!(from: <- tokens)

            // update Farm total
            self.totalStaked = self.totalStaked - amount

            ///// j00lz 2 do check if the update farm needs to go above the depositing above.... possibly balance changes?
            self.updateFarm()
            let pending = (stakeRef.lpTokenVault.balance * self.totalAccumulatedTokensPerShare) - stakeRef.totalClaimed 

            // distribute pending 
            let rewards <- StakingRewards.vault.withdraw(amount: pending)
            let rewardsReceiverRef = stakeControllerRef.rewardsReceiverCap.borrow()!
            rewardsReceiverRef.deposit(from: <- rewards)
            stakeRef.updateTotalClaimed(total: stakeRef.lpTokenVault.balance * self.totalAccumulatedTokensPerShare)
        }

        // Payout Rewards
        pub fun payoutRewards(stakeRef: &Stake) {

            if (stakeRef.lpTokenVault.balance > 0.0) { // if user has an existing stake balance
                let pending = (stakeRef.lpTokenVault.balance * self.totalAccumulatedTokensPerShare) - stakeRef.totalClaimed
                // distribute pending 
                let rewards <- StakingRewards.vault.withdraw(amount: pending)
                stakeRef.rewardsReceiverCap.borrow()!.deposit(from: <-rewards)
                stakeRef.updateTotalClaimed(total: stakeRef.lpTokenVault.balance * self.totalAccumulatedTokensPerShare)
            } 
        }    

        // internal function that is called every time there is a change to the Farm
        pub fun updateFarm() {
            
            let now = getCurrentBlock().timestamp

            if now <= self.lastRewardTimestamp {    // already up to date
                return 
            }

            if self.totalStaked == 0.0 {   // nothing staked so nothing paid out
                self.lastRewardTimestamp = now
                return
            }

            let period = self.lastRewardTimestamp - now // time delta (aka masterchef 'multiplier')
            let reward = period * self.rewardTokensPerSecond 
                         * self.totalAccumulatedTokensPerShare / StakingRewards.totalWeight

            self.totalAccumulatedTokensPerShare = self.totalAccumulatedTokensPerShare + reward / self.totalStaked // allocPoint // original splits this between dev treasury and farm
            self.lastRewardTimestamp = now 
        }

        // Get Pending Rewards Function
        //
        // Gets the total Pending rewards for an address
        //
        pub fun getPendingRewards(address: Address): UFix64 {
            let now = getCurrentBlock().timestamp
            let stakeRef = &self.stakes[address] as &Stake

            if now > self.lastRewardTimestamp && stakeRef.lpTokenVault.balance > 0.0 {
                let delta = now - self.lastRewardTimestamp
                let farmWeight = StakingRewards.farmsByID[stakeRef.lpTokenVault.tokenID]?.totalStaked! / StakingRewards.totalWeight
                let reward = delta * self.rewardTokensPerSecond * farmWeight
                let totalAccumulatedTokensPerShare = self.totalAccumulatedTokensPerShare + (reward / self.totalStaked)
                return stakeRef.lpTokenVault.balance * totalAccumulatedTokensPerShare - stakeRef.totalClaimed
            }
            return 0.0
        }

        pub fun calcPendingRewards() : UFix64 {
            let lastRewardTimestamp = 0.0
            if getCurrentBlock().timestamp > lastRewardTimestamp && self.totalStaked > 0.0 {
                let multiplier = getCurrentBlock().timestamp - lastRewardTimestamp
            }
            
            return 0.0
        }

        init(poolID: UInt64) {
            self.stakes <- {}
            self.totalStaked = 0.0
            self.rewardTokensPerSecond = StakingRewards.getCurrentEmissionRate()
            self.lastRewardTimestamp = getCurrentBlock().timestamp
            self.totalAccumulatedTokensPerShare = 0.0
            self.emuSwapPoolID =poolID
        }

        destroy () {
            destroy self.stakes
        }
    }

    pub resource Admin {
        pub fun createFarm(poolID: UInt64) {
            let newFarm <- create Farm(poolID: poolID)
            let nullResource <- 
                StakingRewards.farmsByID.insert(key: poolID, <- newFarm)
            destroy nullResource
        }
    }

    pub fun updateFarms() {
        for key in self.farmsByID.keys {
            self.farmsByID[key]?.updateFarm()
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
        pub var lpTokenReceiverCap: Capability<&{FungibleTokens.Receiver}>
        pub var rewardsReceiverCap: Capability<&{FungibleToken.Receiver}>
        pub var totalClaimed: UFix64 // aka reward debt

        init(lpTokens: @FungibleTokens.TokenVault, lpTokenReceiverCap: Capability<&{FungibleTokens.Receiver}>, rewardsReceiverCap: Capability<&{FungibleToken.Receiver}>) {
            self.lpTokenVault <- lpTokens
            //self.rewards <- EmuToken.createEmptyVault() // rewards hard coded as EmuToken
            self.lpTokenReceiverCap = lpTokenReceiverCap
            self.rewardsReceiverCap = rewardsReceiverCap
            self.totalClaimed = 0.0
        }

        access(contract) fun updateTotalClaimed(total: UFix64) {
            self.totalClaimed = total
        }

        destroy () {
            destroy self.lpTokenVault
        }
    }


    // Stake Controller Resource
    //
    // User's reference to their stake.
    // j00lz note maybe best to just store the Caps here... is that possible?
    //
    pub resource StakeController {
        pub let farmID: UInt64
        pub let lpTokenReceiverCap: Capability<&{FungibleTokens.Receiver}>
        pub let rewardsReceiverCap: Capability<&{FungibleToken.Receiver}>
        init(id: UInt64, lpTokenReceiverCap: Capability<&{FungibleTokens.Receiver}>, rewardsReceiverCap: Capability<&{FungibleToken.Receiver}>) {
            self.farmID = id
            self.lpTokenReceiverCap = lpTokenReceiverCap
            self.rewardsReceiverCap = rewardsReceiverCap
        }

        pub fun unstake() {

        }

        pub fun claimRewards() {

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

        init() {
            self.ownedStakeControllers <- {}
        }
        destroy () {
            destroy self.ownedStakeControllers
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
        pub let allocPoint: UFix64;         // How many allocation points assigned to this Farm. EmuTokens to distribute per second.
        pub let lastRewardTimestamp: UFix64 // Last timestamp that EmuToken distribution occured
        pub let accEmuPerShare: UFix64      // Accumulated EmuTokens per share, times 1e12. See below.
        init(FarmRef: &Farm) {
            self.id = 0
            self.allocPoint = 0.0
            self.lastRewardTimestamp = getCurrentBlock().timestamp
            self.accEmuPerShare = 0.0
        }
    }

    // Withdraw LP tokens from MasterChef.
    pub fun withdraw(FarmID: UInt64, amount: UFix64) {
        /*
        FarmInfo storage Farm = FarmInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");

        updateFarm(_pid);
        uint256 pending = user.amount.mul(Farm.accJoePerShare).div(1e12).sub(user.rewardDebt);
        safeJoeTransfer(msg.sender, pending);
        user.amount = user.amount.sub(_amount);
        Farm.lpToken.safeTransfer(address(msg.sender), _amount);
        user.rewardDebt = user.amount.mul(Farm.accJoePerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
         */
    }

    // Admin Functions
    //
    // j00lz 2do wrap these in Admin resource or somehow restrict activity
    
    /*
        
        40 M tokens over 3 years

        tokensPerSecond = 1
        reduced by 5.964249 % every 31 days..... for 3 years 3 weeks 

    */
    pub fun getCurrentEmissionRate(): UFix64 {
        var rate = 1.0
        let decay = 0.05964249
        let now = getCurrentBlock().timestamp
        let genesisTimestamp = StakingRewards.rewardsGenesisTimestamp
        // we have 37 epochs of 31 days for 3 years and 3 weeks 
        // joolz recalibrate to 28 days lunar calendar :D 
        let epochLength = 31.0 * 24.0 * 60.0 * 60.0 

        let elapsedTime = now - genesisTimestamp
        var currentEpoch = (elapsedTime / epochLength) - 
                           (elapsedTime % epochLength) 

        while currentEpoch != 0.0 {
            rate = rate * (1.0-decay)
            currentEpoch = currentEpoch - 1.0
        }

        return rate
    }

    init() {
        self.vault <- EmuToken.createEmptyVault()
        self.rewardsGenesisTimestamp = 0.0
        self.farmsByID <- {}
        self.farmWeightsByID = {}
        self.totalWeight = 0.0

        /*
            self.emuPerSec = 0.00000001
            self.devPercent = 0.1
            self.treasuryPercent = 0.1
            self.vault <- EmuToken.createEmptyVault() 
            self.Farms <- {}
         */
    }
}
