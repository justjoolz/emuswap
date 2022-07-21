import FungibleToken from "./dependencies/FungibleToken.cdc"

pub contract Vesting {

    access(contract) let vestingTokens: @{Address: VestingTokens}

    pub resource VestingTokens {
        pub let address: Address
        pub let initalBalance: UFix64
        pub let lockedFrom: UFix64
        pub let duration: UFix64
        pub let tokens: @FungibleToken.Vault 
        pub var tokensWithdrawn: UFix64

        init(tokens: @FungibleToken.Vault, address: Address) {
            self.address = address
            self.initalBalance = tokens.balance
            self.lockedFrom = getCurrentBlock().timestamp
            self.duration = 60.0 * 60.0 * 24.0 * 365.0 * 3.0 // 94,608,000 seconds = 3 years 
            self.tokens <- tokens
            self.tokensWithdrawn = 0.0
        }

        pub fun getCurrentUnlockAllowance(): UFix64 {
            let now = getCurrentBlock().timestamp
            let totalTimeVested = now - self.lockedFrom
            if totalTimeVested > self.lockedFrom + self.duration { // vesting complete allow to withdraw any remaining
                return self.tokens.balance
            }
            let tokensPerSecond = self.initalBalance / self.duration   
            let allowance = totalTimeVested * tokensPerSecond - self.tokensWithdrawn
            return allowance
        }

        pub fun withdrawTokens(amount: UFix64): @FungibleToken.Vault {
            pre {
                amount <= self.getCurrentUnlockAllowance(): "Attempting to withdraw more than allowance"
                amount > 0.0 : "Cannot withdraw 0 tokens?!"
            }
            self.tokensWithdrawn = self.tokensWithdrawn + amount
            return <- self.tokens.withdraw(amount: amount)
        }

        destroy () {
            destroy self.tokens
        }
    }

    pub fun addVesting(address: Address, tokens: @FungibleToken.Vault) {
        pre {
            self.vestingTokens[address] == nil : "This address is already vesting! Contract only supports one vesting token per address"  
        }
        let vestedTokens <- create VestingTokens(tokens: <- tokens, address: address)
        self.vestingTokens[address] <-! vestedTokens
    }

    pub fun getCurrentUnlockAllowance(address: Address): UFix64 {
        return self.vestingTokens[address]?.getCurrentUnlockAllowance()!
    }

    pub fun withdrawTokens(amount: UFix64, tokenReceiver: Capability<&{FungibleToken.Receiver}>) {
        tokenReceiver.borrow()!.deposit(from: <- self.vestingTokens[tokenReceiver.address]?.withdrawTokens(amount: amount)!)
    }

    init() {
        self.vestingTokens <- {}
        let teamTokens <- self.account.load<@FungibleToken.Vault>(from: /storage/teamTokens) ?? panic("Could not find team tokens to vest! Must be deployed after EmuToken!")
        
        let teamAddresses: [Address] = [self.account.address, 0x2234, 0x3234, 0x4234]
        let amount = teamTokens.balance / UFix64(teamAddresses.length)

        for address in teamAddresses {
            self.addVesting(address: address, tokens: <- teamTokens.withdraw(amount: amount))
        }

        assert(teamTokens.balance == 0.0, message: "tokens not fully distributed!")
        destroy teamTokens
    }
}