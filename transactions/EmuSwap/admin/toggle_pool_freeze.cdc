// freeze_pool

import EmuSwap from "../../../contracts/exchange/EmuSwap.cdc"

transaction(id: UInt64) {

  let adminRef: &EmuSwap.Admin

  prepare(signer: AuthAccount) {

    self.adminRef = signer.borrow<&EmuSwap.Admin>(from: EmuSwap.AdminStoragePath)
      ?? panic("Could not borrow a reference to EmuSwap Admin")
  }

  execute {
    self.adminRef.togglePoolFreeze(id: id)
  }
}
