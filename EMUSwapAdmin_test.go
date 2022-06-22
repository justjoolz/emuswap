package main

import (
	"fmt"
	"strconv"
	"testing"

	"github.com/bjartek/overflow/overflow"
)

func TestCreateNewPoolFlowFusd(t *testing.T) {
	o := overflow.NewTestingEmulator().Start()

	mintFlowTokens(o, "account", 1000.0)
	mintFlowTokens(o, "user1", 1000.0)
	mintFlowTokens(o, "user2", 1000.0)

	// Setup FUSD Vaults
	setupFUSDVaultWithBalance(o, "account", 1000.0)
	setupFUSDVaultWithBalance(o, "user1", 1000.0)
	setupFUSDVaultWithBalance(o, "user2", 1000.0)

	flowAmount := 100.0
	fusdAmount := 2.5
	FLOW_AMOUNT := fmt.Sprintf("%.8f", flowAmount)
	FUSD_AMOUNT := fmt.Sprintf("%.8f", fusdAmount)
	SIGNER_ADDRESS := "0xf8d6e0586b0a20c7"

	o.TransactionFromFile("/EmuSwap/admin/create_new_pool_FLOW_FUSD").SignProposeAndPayAs("account").
		Args(o.
			Arguments().
			UFix64(flowAmount).
			UFix64(fusdAmount)).
		Test(t).
		AssertSuccess().
		AssertEmitEvent(overflow.NewTestEvent("A.0ae53cb6e3f42a79.FlowToken.TokensWithdrawn", map[string]interface{}{
			"amount": FLOW_AMOUNT,
			"from":   SIGNER_ADDRESS,
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.FUSD.TokensWithdrawn", map[string]interface{}{
			"amount": FUSD_AMOUNT,
			"from":   SIGNER_ADDRESS,
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.TokensInitialized", map[string]interface{}{
			// "tokenA":  "",
			// "tokenB":  "",
			"tokenID": "0",
		})).
		// ?
		AssertEmitEvent(overflow.NewTestEvent("A.0ae53cb6e3f42a79.FlowToken.TokensWithdrawn", map[string]interface{}{
			"amount": FLOW_AMOUNT,
			"from":   "",
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.FUSD.TokensWithdrawn", map[string]interface{}{
			"amount": FUSD_AMOUNT,
			"from":   "",
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.TokensMinted", map[string]interface{}{
			"amount":  "1.00000000",
			"tokenID": "0",
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.NewSwapPoolCreated", map[string]interface{}{})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.PoolIsFrozen", map[string]interface{}{
			"id":       "0",
			"isFrozen": "false",
		})).
		// AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.TokensDeposited", map[string]interface{}{
		// 	"amount":  "1.00000000",
		// 	"to":      "",
		// 	"tokenID": "0",
		// })).
		AssertEventCount(9)
}

func TestCreateNewPoolEmuFusd(t *testing.T) {

	o := overflow.NewTestingEmulator().Start()

	mintFlowTokens(o, "account", 1000.0)
	mintFlowTokens(o, "user1", 1000.0)
	mintFlowTokens(o, "user2", 1000.0)

	// Setup FUSD Vaults
	setupFUSDVaultWithBalance(o, "account", 1000.0)
	setupFUSDVaultWithBalance(o, "user1", 1000.0)
	setupFUSDVaultWithBalance(o, "user2", 1000.0)

	emuAmount := 100.0
	fusdAmount := 100.0

	EMU_AMOUNT := fmt.Sprintf("%.8f", emuAmount)
	FUSD_AMOUNT := fmt.Sprintf("%.8f", fusdAmount)
	SIGNER_ADDRESS := "0xf8d6e0586b0a20c7"

	o.TransactionFromFile("/EmuSwap/admin/create_new_pool_EMU_FUSD").SignProposeAndPayAs("account").
		Args(o.
			Arguments().
			UFix64(emuAmount).
			UFix64(fusdAmount)).
		Test(t).
		AssertSuccess().
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuToken.TokensWithdrawn", map[string]interface{}{
			"amount": EMU_AMOUNT,
			"from":   SIGNER_ADDRESS,
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.FUSD.TokensWithdrawn", map[string]interface{}{
			"amount": FUSD_AMOUNT,
			"from":   SIGNER_ADDRESS,
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.TokensInitialized", map[string]interface{}{
			"tokenID": "0",
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuToken.TokensWithdrawn", map[string]interface{}{
			"amount": EMU_AMOUNT,
			"from":   "",
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.FUSD.TokensWithdrawn", map[string]interface{}{
			"amount": FUSD_AMOUNT,
			"from":   "",
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.TokensMinted", map[string]interface{}{
			"amount":  "1.00000000",
			"tokenID": "0",
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.NewSwapPoolCreated", map[string]interface{}{})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.PoolIsFrozen", map[string]interface{}{
			"id":       "0",
			"isFrozen": "false",
		})).
		//
		// AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.TokensDeposited", map[string]interface{}{
		// 	"amount":  "1.00000000",
		// 	"to":      "",
		// 	"tokenID": "0",
		// })).
		AssertEventCount(9)
}

func TestCreateNewPool(t *testing.T) {
	o := overflow.NewTestingEmulator().Start()

	mintFlowTokens(o, "account", 1000.0)
	mintFlowTokens(o, "user1", 1000.0)
	mintFlowTokens(o, "user2", 1000.0)

	// Setup FUSD Vaults
	setupFUSDVaultWithBalance(o, "account", 1000.0)
	setupFUSDVaultWithBalance(o, "user1", 1000.0)
	setupFUSDVaultWithBalance(o, "user2", 1000.0)

	flowAmount := 100.0
	fusdAmount := 2.5
	flowStoragePath := "flowTokenVault"
	fusdStoragePath := "fusdVault"

	testCreatePool(o, t, flowStoragePath, flowAmount, fusdStoragePath, fusdAmount)
}

func testCreatePool(o *overflow.Overflow, t *testing.T, token1identifier string, token1Amount float64, token2identifier string, token2Amount float64) {
	o.TransactionFromFile("/EmuSwap/admin/create_new_pool").SignProposeAndPayAs("account").
		Args(o.
			Arguments().
			String(token1identifier).
			UFix64(token1Amount).
			String(token2identifier).
			UFix64(token2Amount)).
		Test(t).
		AssertSuccess().
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.TokensInitialized", map[string]interface{}{
			"tokenID": "0",
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.TokensMinted", map[string]interface{}{
			"amount":  "1.00000000",
			"tokenID": "0",
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.NewSwapPoolCreated", map[string]interface{}{}))
}

/*

func TestTogglePoolFreeze(t *testing.T) {
	o := overflow.NewTestingEmulator().Start()

	mintFlowTokens(o, "account", 1000.0)
	mintFlowTokens(o, "user1", 1000.0)
	mintFlowTokens(o, "user2", 1000.0)

	// Setup FUSD Vaults
	setupFUSDVaultWithBalance(o, "account", 1000.0)
	setupFUSDVaultWithBalance(o, "user1", 1000.0)
	setupFUSDVaultWithBalance(o, "user2", 1000.0)

	flowAmount := 100.0
	fusdAmount := 2.5
	flowStoragePath := "flowTokenVault"
	fusdStoragePath := "fusdVault"

	testCreatePool(o, t, flowStoragePath, flowAmount, fusdStoragePath, fusdAmount)
	poolID := uint64(0)
	// getPoolMeta(o, poolID)

	o.TransactionFromFile("/EmuSwap/admin/toggle_pool_freeze").SignProposeAndPayAs("account").
		Args(o.
			Arguments().
			UInt64(poolID)).
		Test(t).
		AssertSuccess().
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.PoolIsFrozen", map[string]interface{}{
			"id":       "0",
			"isFrozen": "true",
		}))
}
*/

func TestTogglePoolFreeze(t *testing.T) {
	o := overflow.NewTestingEmulator().Start()
	setupFUSDVaultWithBalance(o, "account", 1000.0)

	flowAmount := 100.0
	fusdAmount := 150.0
	flowStoragePath := "flowTokenVault"
	fusdStoragePath := "fusdVault"

	testCreatePool(o, t, flowStoragePath, flowAmount, fusdStoragePath, fusdAmount)
	testTogglePoolFreeze(o, t, 0)
}

func testTogglePoolFreeze(o *overflow.Overflow, t *testing.T, poolID uint64) {
	o.TransactionFromFile("/EmuSwap/admin/toggle_pool_freeze").SignProposeAndPayAs("account").
		Args(o.
			Arguments().
			UInt64(poolID)).
		Test(t).
		AssertSuccess().
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.PoolIsFrozen", map[string]interface{}{
			"id":       strconv.FormatUint(poolID, 10),
			"isFrozen": "true",
		}))
}

// func (otu *OverflowTestUtils) NewOverFlowTest(t *testing.T) *OverflowTestUtils {
// 	return &OverflowTestUtils{T: t, O: overflow.NewTestingEmulator().Start()}
// }

// func (otu *OverflowTestUtils) mintFlowTokens(o *overflow.Overflow, account string, amount float64) *OverflowTestUtils {
// 	otu.O.TransactionFromFile("demo/mintFlowTokens").
// 		SignProposeAndPayAs("account").
// 		Args(o.Arguments().
// 			UFix64(amount).
// 			Account(account)).
// 		Test(otu.T).AssertSuccess()
// 	return otu
// }