import Vesting from "../../contracts/Vesting.cdc"  
import EmuToken from "../../contracts/EmuToken.cdc"  
import FungibleToken from "../../contracts/dependencies/FungibleToken.cdc"  

transaction() {
    prepare(acct: AuthAccount) {
        let address = acct.address
        let amount = Vesting.getCurrentUnlockAllowance(address: address)
        let tokenReceiver = acct.getCapability<&{FungibleToken.Receiver}>(EmuToken.EmuTokenReceiverPublicPath)
        Vesting.withdrawTokens(amount: amount, tokenReceiver: tokenReceiver)
    }
}
