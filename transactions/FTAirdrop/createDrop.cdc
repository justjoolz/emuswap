import FTAirdrop from "../../contracts/FTAirdrop.cdc"
import FungibleToken from "../../contracts/dependencies/FungibleToken.cdc"

transaction(amount: UFix64) { // startTime: UFix64, duration: UFix64, claims: {Address: UFix64}
    prepare(signer: AuthAccount) {
        if signer.borrow<&FTAirdrop.DropControllerCollection>(from: FTAirdrop.DropControllerStoragePath) == nil {
            let collection <- FTAirdrop.createEmptyDropCollection()
            signer.save(<- collection, to: FTAirdrop.DropControllerStoragePath)
        }
        
        let vault = signer.borrow<&FungibleToken.Vault>(from: /storage/flowTokenVault)
        let tokens <- vault!.withdraw(amount: amount)
        let startTime = getCurrentBlock().timestamp + 100.0
        let duration = 100000.0
        let ftReceiverCap = signer.getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
        let claims: {Address: UFix64} = {signer.address: 10.0}
        let collection = signer.borrow<&FTAirdrop.DropControllerCollection>(from: FTAirdrop.DropControllerStoragePath)
        let drop <- FTAirdrop.createDrop(tokens: <- tokens, startTime: startTime, duration: duration, ftReceiverCap: ftReceiverCap, claims: claims)

        collection!.deposit(drop: <- drop)
    }
}