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

	poolID := getNextPoolID(o)

	flowAmount := 100.0
	fusdAmount := 2.5

	FLOW_AMOUNT := fmt.Sprintf("%.8f", flowAmount)
	FUSD_AMOUNT := fmt.Sprintf("%.8f", fusdAmount)
	SIGNER_ADDRESS := "0xf8d6e0586b0a20c7"
	TOKEN_ID := fmt.Sprintf("%d", poolID)

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
			"tokenID": TOKEN_ID,
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
			"tokenID": TOKEN_ID,
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.NewSwapPoolCreated", map[string]interface{}{
			"poolID": TOKEN_ID,
			"tokenA": "A.0ae53cb6e3f42a79.FlowToken",
			"tokenB": "A.f8d6e0586b0a20c7.FUSD",
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.PoolIsFrozen", map[string]interface{}{
			"id":       TOKEN_ID,
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
	POOL_ID := fmt.Sprintf("%d", getNextPoolID(o))

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
			"tokenID": POOL_ID,
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
			"tokenID": POOL_ID,
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.NewSwapPoolCreated", map[string]interface{}{
			"poolID": POOL_ID,
			"tokenA": "A.f8d6e0586b0a20c7.EmuToken",
			"tokenB": "A.f8d6e0586b0a20c7.FUSD",
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.PoolIsFrozen", map[string]interface{}{
			"id":       POOL_ID,
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

	testCreateSwapPool(o, t, flowStoragePath, flowAmount, fusdStoragePath, fusdAmount)
}

func testCreateSwapPool(o *overflow.Overflow, t *testing.T, token1identifier string, token1Amount float64, token2identifier string, token2Amount float64) uint64 {

	id := getNextPoolID(o)
	TOKEN_ID := fmt.Sprintf("%d", id)

	TOKEN_A := storagePathToTokenIdentifier(token1identifier) // "A.0ae53cb6e3f42a79.FlowToken"
	TOKEN_B := storagePathToTokenIdentifier(token2identifier) // "A.f8d6e0586b0a20c7.FUSD"

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
			"tokenID": TOKEN_ID,
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.TokensMinted", map[string]interface{}{
			"amount":  "1.00000000",
			"tokenID": TOKEN_ID,
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.NewSwapPoolCreated", map[string]interface{}{
			"poolID": TOKEN_ID,
			"tokenA": TOKEN_A,
			"tokenB": TOKEN_B,
		}))

	return uint64(id)
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

	testCreateSwapPool(o, t, flowStoragePath, flowAmount, fusdStoragePath, fusdAmount)
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

	testCreateSwapPool(o, t, flowStoragePath, flowAmount, fusdStoragePath, fusdAmount)
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

func TestWithdrawFees(t *testing.T) {
	o := overflow.NewTestingEmulator().Start()
	testSetupEmuToken(o, t, "user1")

	mintFlowTokens(o, "account", 1000.0)
	mintFlowTokens(o, "user1", 1000.0)

	// Setup FUSD Vaults
	setupFUSDVaultWithBalance(o, "account", 1000.0)
	setupFUSDVaultWithBalance(o, "user1", 1000.0)

	token1StorageID := "flowTokenVault"
	token2StorageID := "fusdVault"
	token1Amount := 100.0
	token2Amount := 150.0

	testCreateSwapPool(o, t, token1StorageID, token1Amount, token2StorageID, token2Amount)
	testCreateSwapPool(o, t, token1StorageID, token1Amount, "emuTokenVault", token2Amount)
	amount := 0.1

	signer := "user1"

	testSwap(o, t, signer, token1StorageID, token2StorageID, amount)
	testSwap(o, t, signer, token1StorageID, "emuTokenVault", amount)
	testSwap(o, t, signer, "emuTokenVault", token1StorageID, amount)
	testWithdrawFees(o, t)
}

func testWithdrawFees(o *overflow.Overflow, t *testing.T) {
	o.TransactionFromFile("EmuSwap/admin/withdraw_fees").SignProposeAndPayAsService().
		Test(t).
		AssertSuccess().
		AssertEmitEventName("A.f8d6e0586b0a20c7.xEmuToken.FeesReceived")
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
