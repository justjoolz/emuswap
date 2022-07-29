package main

import (
	"testing"

	"github.com/bjartek/overflow/overflow"
)

func TestSetupEmuToken(t *testing.T) {
	o := overflow.NewTestingEmulator().Start()
	testSetupEmuToken(o, t, "user1")
}

func testSetupEmuToken(o *overflow.Overflow, t *testing.T,
	account string) {

	o.TransactionFromFile("/EmuToken/setup").SignProposeAndPayAs(account).
		Test(t).
		AssertSuccess()
}
