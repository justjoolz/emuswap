import FTAirdrop from "../../contracts/FTAirdrop.cdc"
import FungibleToken from "../../contracts/dependencies/FungibleToken.cdc"

transaction(id: UInt64, ftReceiverIdentifier: String) { // startTime: UFix64, duration: UFix64, claims: {Address: UFix64}
    prepare(signer: AuthAccount) {
        let ftReceiverCap = signer.getCapability<&{FungibleToken.Receiver}>(PublicPath(identifier: ftReceiverIdentifier)!)
        FTAirdrop.claimDrop(dropID: id, ftReceiverCap: ftReceiverCap)
    }
}