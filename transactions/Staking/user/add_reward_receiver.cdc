// transaction to add a FT receiver cap to a farm to receive custom reward pools

import FungibleToken from "../../../contracts/dependencies/FungibleToken.cdc"
import StakingRewards from "../../../contracts/StakingRewards.cdc"

transaction(farmID: UInt64, ftReceiverCap: String, vaultPath: String) {
    prepare(signer: AuthAccount) {
        let stakeController = signer.borrow<&StakingRewards.StakeControllerCollection>(from: StakingRewards.CollectionStoragePath)!
        let capPath = PublicPath(identifier: ftReceiverCap)!
        let cap = signer.getCapability<&{FungibleToken.Receiver}>(capPath) 
        
        if cap == nil {
            signer.link<&{FungibleToken.Receiver}>(capPath, target: StoragePath(identifier: vaultPath)!)    
        }
        stakeController.borrow(id: farmID)!.addRewardReceiverCap(id: farmID, capability: cap)
    }
}