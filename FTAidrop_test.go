package main

import (
	"encoding/json"
	"fmt"
	"testing"

	"github.com/bjartek/overflow/overflow"
)

func TestSetupFTAirDrop(t *testing.T) {
	o := overflow.NewTestingEmulator().Start()
	mintFlowTokens(o, "user1", 100000.0)
	testSetupFTAirDrop(o, t, "user1")
	testSetupFTAirDrop(o, t, "user1")
	testClaimAirdrop(o, t, "user1", 0)
	testClaimAirdrop(o, t, "user1", 1)
	// panic("shizzle")
}

func testSetupFTAirDrop(o *overflow.Overflow, t *testing.T,
	account string) {
	amount := 10.0

	// o.ScriptFromFile()

	o.TransactionFromFile("FTAirdrop/createDrop").SignProposeAndPayAs(account).
		Args(o.Arguments().UFix64(amount)).
		Test(t).
		AssertSuccess().
		AssertEmitEventName("A.f8d6e0586b0a20c7.FTAirdrop.DropCreated").
		// AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.FTAirdrop.DropCreated", map[string]interface{}{
		// 	"address": "0x179b6b1cb6755e31",
		// 	"amount":  "10.00000000",
		// 	"id":      DROP_ID,
		// })).
		AssertEventCount(2)

	data := o.ScriptFromFile("FTAirdrop/checkAvailableClaims").Args(o.Arguments().Account(account)).RunReturnsJsonString()
	fmt.Print(data)
}

type Claim struct {
	Amount json.Number
	Id     json.Number
	Type   string
}

func testClaimAirdrop(
	o *overflow.Overflow,
	t *testing.T,

	account string,
	dropID uint64,
) {
	ftTokenReceiver := "flowTokenReceiver"
	DROP_ID := fmt.Sprint(dropID)

	// o.ScriptFromFile("FTAidrop/checkDrop")
	CONTRACT_ADDRESS := "0xf8d6e0586b0a20c7"
	ACCOUNT_ADDRESS := "0x179b6b1cb6755e31" // Sprint(account)

	var data []Claim
	o.ScriptFromFile("FTAirdrop/checkAvailableClaims").Args(o.Arguments().Account(account)).RunMarshalAs(&data)

	o.TransactionFromFile("FTAirdrop/claimDrop").SignProposeAndPayAs(account).
		Args(o.Arguments().
			UInt64(dropID).
			String(ftTokenReceiver)).
		Test(t).
		AssertSuccess().
		AssertEmitEventName("A.f8d6e0586b0a20c7.FTAirdrop.DropClaimed").
		AssertEmitEvent(overflow.NewTestEvent("A.0ae53cb6e3f42a79.FlowToken.TokensWithdrawn", map[string]interface{}{
			"amount": "10.00000000",
			"from":   CONTRACT_ADDRESS,
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.0ae53cb6e3f42a79.FlowToken.TokensDeposited", map[string]interface{}{
			"amount": "10.00000000",
			"to":     ACCOUNT_ADDRESS,
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.FTAirdrop.DropClaimed", map[string]interface{}{
			"address": ACCOUNT_ADDRESS,
			"amount":  "10.00000000",
			"id":      DROP_ID,
		})).
		AssertEventCount(3)

	// data := o.ScriptFromFile("FTAirdrop/checkAvailableClaims").Args(o.Arguments().Account(account)).RunReturnsJsonString()
	fmt.Print(data)
	// panic(data)
}
