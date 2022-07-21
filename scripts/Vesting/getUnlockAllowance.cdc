import Vesting from "../../contracts/Vesting.cdc"

pub fun main(address: Address): UFix64 {
    return Vesting.getCurrentUnlockAllowance(address: address)
}