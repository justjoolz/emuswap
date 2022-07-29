// freeze_pool

import EmuSwap from "../../../contracts/EmuSwap.cdc"
import xEmuToken from "../../../contracts/xEmuToken.cdc"

transaction() {

  let adminRef: &EmuSwap.Admin

  prepare(signer: AuthAccount) {

    self.adminRef = signer.borrow<&EmuSwap.Admin>(from: EmuSwap.AdminStoragePath)
      ?? panic("Could not borrow a reference to EmuSwap Admin")
  }

  execute {
    EmuSwap.sendEmuFeesToDAO()
  }
}
