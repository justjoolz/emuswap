// Demo transaction to setup mint flow for deploying contracts to admin account 

import FungibleToken from "../../contracts/dependencies/FungibleToken.cdc" 
import FlowToken from "../../contracts/dependencies/FlowToken.cdc"

transaction(amount: UFix64, recipientAddress: Address) {
  prepare(signer: AuthAccount) {

    // get reference to flow admin resource
    let flowTokenAdmin = signer.borrow<&FlowToken.Administrator>(from: /storage/flowTokenAdmin) ?? panic("no flow token administrator found in storage")

    // create a new minter
    let minter <- flowTokenAdmin.createNewMinter(allowedAmount: amount)

    let tokens <- minter.mintTokens(amount: amount)
   
    destroy minter
    
    // borrow recipients
    let accountRef = getAccount(recipientAddress)
          .getCapability(/public/flowTokenReceiver)
          .borrow<&{FungibleToken.Receiver}>()  ?? panic("Cannot borrow account: ".concat(recipientAddress.toString()).concat(" flowTokenReceiver Cap"))

    accountRef.deposit( from: <- tokens )
  }
}