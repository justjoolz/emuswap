package main

import (
	"testing"

	"github.com/bjartek/overflow/overflow"
)

func TestSetupXEmuToken(t *testing.T) {
	o := overflow.NewTestingEmulator().Start()
	testSetupXEmuToken(o, t, "user1")
}

func testSetupXEmuToken(o *overflow.Overflow, t *testing.T,
	account string) {

	o.TransactionFromFile("/EmuToken/setup").SignProposeAndPayAs(account).
		Test(t).
		AssertSuccess()
}
