package main

import (
	"fmt"
	"testing"

	"github.com/bjartek/overflow/overflow"
)

func TestAddLiquidity(t *testing.T) {
	o := overflow.NewTestingEmulator().Start()

	mintFlowTokens(o, "account", 1000.0)
	mintFlowTokens(o, "user1", 1000.0)

	// Setup FUSD Vaults
	setupFUSDVaultWithBalance(o, "account", 1000.0)
	setupFUSDVaultWithBalance(o, "user1", 1000.0)

	token1StorageID := "flowTokenVault"
	token2StorageID := "fusdVault"
	token1Amount := 100.0
	token2Amount := 2.5

	testCreatePool(o, t, token1StorageID, token1Amount, token2StorageID, token2Amount)
	addLiquidity(o, t, "account", token1StorageID, token1Amount, token2StorageID, token2Amount)
	addLiquidity(o, t, "user1", token1StorageID, token1Amount, token2StorageID, token2Amount)
}

func addLiquidity(
	o *overflow.Overflow,
	t *testing.T,
	signer string,

	token1StorageID string,
	token1Amount float64,
	token2StorageID string,
	token2Amount float64) {

	TOKEN_1_AMOUNT := fmt.Sprintf("%.8f", token1Amount)
	TOKEN_2_AMOUNT := fmt.Sprintf("%.8f", token2Amount)
	SIGNER_ADDRESS := "0x" + o.Account(signer).Address().String()

	o.TransactionFromFile("/EmuSwap/user/add_liquidity").SignProposeAndPayAs(signer).
		Args(o.
			Arguments().
			String(token1StorageID).
			UFix64(token1Amount).
			String(token2StorageID).
			UFix64(token2Amount)).
		Test(t).
		AssertSuccess().
		AssertEmitEvent(overflow.NewTestEvent("A.0ae53cb6e3f42a79.FlowToken.TokensWithdrawn", map[string]interface{}{
			"amount": TOKEN_1_AMOUNT,
			"from":   SIGNER_ADDRESS,
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.FUSD.TokensWithdrawn", map[string]interface{}{
			"amount": TOKEN_2_AMOUNT,
			"from":   SIGNER_ADDRESS,
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.0ae53cb6e3f42a79.FlowToken.TokensWithdrawn", map[string]interface{}{
			"amount": TOKEN_1_AMOUNT,
			"from":   "",
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.FUSD.TokensWithdrawn", map[string]interface{}{
			"amount": TOKEN_2_AMOUNT,
			"from":   "",
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.TokensMinted", map[string]interface{}{
			"amount":  "1.00000000", // j00lz 1.00000000 is hardcoded... need to calculate value in advance based on lpAmount vs totalLiquidity
			"tokenID": "0",
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.TokensDeposited", map[string]interface{}{
			"amount":  "1.00000000",
			"to":      SIGNER_ADDRESS,
			"tokenID": "0",
		})).
		AssertEventCount(8)
}

func TestAddRewardReceiver(t *testing.T) {
	o := overflow.NewTestingEmulator().Start()

	setupFUSDVaultWithBalance(o, "account", 100.0)
	testCreatePool(o, t, "flowTokenVault", 100.0, "fusdVault", 100.0)

	signer := "account"
	farmID := uint64(0)
	publicReceiver := "emuTokenReceiver"
	storagePath := "emuTokenVault"

	testCreateNewFarm(o, t, 0)
	testFirstStake(o, t, signer, farmID, 1.0)
	testAddRewardReceiver(o, t, signer, farmID, publicReceiver, storagePath)
}

func testAddRewardReceiver(o *overflow.Overflow, t *testing.T,
	signer string,

	farmID uint64,
	publicReceiver string,
	storagePath string) {
	o.TransactionFromFile("Staking/user/add_reward_receiver").SignProposeAndPayAs(signer).
		Args(o.
			Arguments().
			UInt64(farmID).
			String(publicReceiver).
			String(storagePath)).
		Test(t).
		AssertSuccess().
		AssertEventCount(0)
}
