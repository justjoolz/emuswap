package main

import (
	"fmt"
	"testing"

	"github.com/bjartek/overflow/overflow"
	"github.com/stretchr/testify/assert"
)

// This story creates 3 pools.... does a bunch of swaps and then swaps all the collected fees for EmuTokens and sends them to the xEmuToken contract
func TestStory(t *testing.T) {
	o := overflow.NewTestingEmulator().Start()
	testSetupEmuToken(o, t, "user1")
	setupFUSDVaultWithBalance(o, "account", 1000.0)
	setupFUSDVaultWithBalance(o, "user1", 1000.0)
	mintFlowTokens(o, "user1", 1000.0)

	flowAmount := 100.0
	fusdAmount := 150.0
	emuAmount := 100.0
	flowStoragePath := "flowTokenVault"
	fusdStoragePath := "fusdVault"
	emuStoragePath := "emuTokenVault"
	// farmID := uint64(0)

	// ADMIN
	// Create EmuSwap Pool
	testCreateSwapPool(o, t, flowStoragePath, flowAmount, fusdStoragePath, fusdAmount) // flow:fusd  id 0
	testCreateSwapPool(o, t, flowStoragePath, flowAmount, emuStoragePath, emuAmount)   // flow:emu   id 1
	testCreateSwapPool(o, t, fusdStoragePath, fusdAmount, emuStoragePath, emuAmount)   // fusd:emu   id 2

	// Test Swaps
	testSwap(o, t, "account", flowStoragePath, fusdStoragePath, 100.0) // flow -> fusd
	testSwap(o, t, "account", fusdStoragePath, flowStoragePath, 100.0) // fusd -> flow

	testSwap(o, t, "account", flowStoragePath, emuStoragePath, 1.0) // flow -> emu
	testSwap(o, t, "account", emuStoragePath, flowStoragePath, 1.0) // emu  -> flow

	fmt.Println("Testing swapping fsud->emu")
	testSwap(o, t, "account", emuStoragePath, fusdStoragePath, 1.0) // emu -> fusd
	testSwap(o, t, "account", fusdStoragePath, emuStoragePath, 1.0) // fusd -> emu

	testWithdrawFees(o, t)
}

func TestStory1(t *testing.T) {
	o := overflow.NewTestingEmulator().Start()
	testSetupEmuToken(o, t, "user1")
	setupFUSDVaultWithBalance(o, "account", 1000.0)
	setupFUSDVaultWithBalance(o, "user1", 1000.0)
	mintFlowTokens(o, "user1", 1000.0)

	flowAmount := 100.0
	fusdAmount := 150.0
	flowStoragePath := "flowTokenVault"
	fusdStoragePath := "fusdVault"
	farmID := uint64(0)

	// ADMIN
	// Create EmuSwap Pool
	testCreateSwapPool(o, t, flowStoragePath, flowAmount, fusdStoragePath, fusdAmount)

	testCreateNewFarm(o, t, farmID)
	// testAddLiquidityAndStake(o, t, "account", 0, flowAmount, fusdAmount)

	// toggleMockTime(o, t)
	// updateMockTimestamp(o, t, 1.0)

	addLiquidity(o, t, "user1", flowStoragePath, flowAmount, fusdStoragePath, fusdAmount)
	// testAddLiquidityAndStake(o, t, "user1", 0, 100.0, 150.0)

	lpAmount := 1.0
	factor := 1.0
	sessionLength := 100.0 // 60.0 * 60.0 * 24.0 // testing 2 session of staking

	// both users stake (account stakes a fraction of user1)
	testFirstStake(o, t, "account", farmID, lpAmount/factor)
	testFirstStake(o, t, "user1", farmID, lpAmount)
	// testStake(o, t, "user1", farmID, lpAmount)

	// time.Sleep(1 * time.Second)
	updateMockTimestamp(o, t, sessionLength) // even though we sleep we need to send a tx to bump the current block
	// updateMockTimestamp(o, t, sessionLength) // even though we sleep we need to send a tx to bump the current block
	// account stakes same amount again
	// testStake(o, t, "account", farmID, lpAmount/factor)
	// testStake(o, t, "user1", farmID, lpAmount*2)

	// same amount of time elapses
	// updateMockTimestamp(o, t, sessionLength) // event though we sleep we need to send a tx to bump the current block

	publicReceiver := "emuTokenReceiver"
	storagePath := "emuTokenVault"
	// testAddRewardReceiver(o, t, "user1", farmID, publicReceiver, storagePath)
	testAddRewardReceiver(o, t, "user1", farmID, publicReceiver, storagePath)

	user1Claimed := claimRewards(o, t, "account", farmID)
	user2Claimed := claimRewards(o, t, "user1", farmID)
	assert.Equal(t, user1Claimed, roundFloat(user2Claimed/factor))
	// assert.Equal(t, user1Claimed/roundFloat(user2Claimed/factor), 1.0)
	// assert.Equal(t, user2Claimed/roundFloat(user1Claimed/factor), 0.0)
	// assert.Equal(t, user1Claimed-roundFloat(user2Claimed/factor), 0.0)

}
