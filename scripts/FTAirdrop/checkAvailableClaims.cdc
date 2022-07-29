import FTAirdrop from "../../contracts/FTAirdrop.cdc"

pub fun main(address: Address): AnyStruct {
    return FTAirdrop.checkAvailableClaims(address: address)
}