// Demo transaction to setup demo accounts 

// 1. Creates a Flow minter and saves in emulator account storage
// 2. Mints 2x1000 tokens
// 3. Transfers to (hardcoded) demo user address 

import FungibleToken from "../../contracts/dependencies/FungibleToken.cdc" 
import FUSD from "../../contracts/dependencies/FUSD.cdc"

transaction(amount: UFix64, recipientAddress: Address) {
  prepare(signer: AuthAccount) {

    let fusdTokenAdmin = signer.borrow<&FUSD.Administrator>(from: FUSD.AdminStoragePath) ?? panic("no flow token administrator found in storage")

    let minter <- fusdTokenAdmin.createNewMinter()

    let tokens <- minter.mintTokens(amount: amount)
  
    destroy minter
    
    let receiverRef = getAccount(recipientAddress)
          .getCapability(/public/fusdReceiver)
          .borrow<&{FungibleToken.Receiver}>()  
          ?? panic("Cannot borrow account: 0x01cf0e2f2f715450 fusdTokenReceiver Cap")

   
    receiverRef.deposit(from: <- tokens)
  }
}