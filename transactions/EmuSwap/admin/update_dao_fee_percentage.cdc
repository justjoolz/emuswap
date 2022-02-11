// update_fee_percentage
//
// Updates the Fee for LP Providers

import EmuSwap from "../../../contracts/exchange/EmuSwap.cdc"

transaction(feePercentage: UFix64) {

  let adminRef: &EmuSwap.Admin

  prepare(signer: AuthAccount) {

    self.adminRef = signer.borrow<&EmuSwap.Admin>(from: EmuSwap.AdminStoragePath)
      ?? panic("Could not borrow a reference to EmuSwap Admin")
    
  }

  execute {
      self.adminRef.updateDAOFeePercentage(feePercentage: feePercentage)
  }
}