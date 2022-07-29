package main

import (
	"encoding/json"
	"fmt"
	"math"
	"testing"

	"github.com/bjartek/overflow/overflow"
	"github.com/stretchr/testify/assert"
)

// j00lz todo: update tests to work with multiple accounts.

func TestAddLiquidityAndStake(t *testing.T) {
	o := overflow.NewTestingEmulator().Start()
	setupFUSDVaultWithBalance(o, "account", 1000.0)

	flowAmount := 100.0
	fusdAmount := 150.0
	flowStoragePath := "flowTokenVault"
	fusdStoragePath := "fusdVault"

	testCreateSwapPool(o, t, flowStoragePath, flowAmount, fusdStoragePath, fusdAmount)

	farmID := uint64(0)
	testCreateNewFarm(o, t, farmID)

	testAddLiquidityAndStake(o, t, "account", farmID, flowAmount, fusdAmount)

	farmMeta := &FarmMeta{}
	err := o.ScriptFromFile("/Staking/get_farm_meta").Args(o.Arguments().UInt64(farmID)).RunMarshalAs(&farmMeta)

	if err != nil {
		panic(err)
	}

	assert.Nil(t, err)
	assert.NotNil(t, farmMeta.LastRewardTimestamp)
	assert.NotEqual(t, farmMeta.LastRewardTimestamp, "0")
	assert.GreaterOrEqual(t, farmMeta.LastRewardTimestamp, "0")

	// assert.Equal(t, farmMeta.id, 0)

	// json := o.ScriptFromFile("/Staking/get_farm_meta").Args(o.Arguments().UInt64(farmID)).RunReturnsJsonString()
	// panic(json)
	// assert.Equal(t, farmMeta.id, uint64(0))
	// assert.Equal(t, farmMeta, uint64(0))

	// /*
	// 	"A.f8d6e0586b0a20c7.StakingRewards.FarmMeta(
	// 		id: 0,
	// 		stakes: {},
	// 		totalStaked: 0.00000000,
	// 		lastRewardTimestamp: 1655367585.00000000,
	// 		farmWeightsByID: {0: 1.00000000, 1: 1.00000000},
	// 		rewardTokensPerSecondByID: {0: 1.00000000, 1: 1.00000000},
	// 		totalAccumulatedTokensPerShareByID: {1: 0.00000000, 0: 0.00000000})")
	// */

	// // no pending rewards
	// pendingRewards := o.ScriptFromFile("/Staking/get_pending_rewards").Args(o.Arguments().UInt64(farmID).Account("account")).RunReturnsInterface()
	// expectedRewards := map[string]interface{}(map[string]interface{}{
	// 	"0": "0.00000000",
	// })
	// assert.Equal(t, pendingRewards, expectedRewards)

	// get stakes
	// var stakes = &StakesInfo{}
	// err := o.ScriptFromFile("/Staking/read_stakes_info").Args(o.Arguments().UInt64(farmID)).RunMarshalAs(&stakes)
	// stakeInfo := o.ScriptFromFile("/Staking/read_stakes_info").Args(o.Arguments().UInt64(farmID)).RunReturnsJsonString() // .RunMarshalAs(&farmMeta)
	// panic(stakeInfo)
	/*
			    "0xf8d6e0586b0a20c7": {
		        "address": "0xf8d6e0586b0a20c7",
		        "balance": "1.00000000",
		        "pendingRewards": {
		            "0": "0.00000000"
		        },
		        "rewardDebtByID": {
		            "0": "0.00000000"
		        }
		    }
	*/
	// m := stakes.(map[string]interface{})
	// var stakesInfo []string
	// for k := range m {
	// 	stakesInfo = append(stakesInfo, k)

	// }

	// if err != nil {
	// 	panic(err)
	// }
	// panic(stakeInfo)
	// assert.Nil(t, stakes)
	// assert.Equal(t, stakes, string("{}"))
	// assert.Equal(t, stakesInfo, string("{}"))
	// assert.Equal(t, stakesInfo[0], string("{}"))
}

// j00l zmaybe remove this and make it two separate tx?
func testAddLiquidityAndStake(o *overflow.Overflow, t *testing.T,
	signer string,

	farmID uint64,
	flowAmount float64,
	fusdAmount float64) {

	o.TransactionFromFile("/Staking/user/add_liquidity_and_stake").SignProposeAndPayAs(signer).
		Args(o.
			Arguments().
			UInt64(farmID).
			UFix64(flowAmount).
			UFix64(fusdAmount)).
		Test(t).
		AssertSuccess().
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.StakingRewards.TokensStaked", map[string]interface{}{
			"address":      "0x" + o.Account(signer).Address().String(),
			"amountStaked": "1.00000000",
			"poolID":       fmt.Sprintf("%d", farmID),
			"totalStaked":  "1.00000000",
		})).
		AssertEventCount(10)

	farmMeta := FarmMeta{}
	err := o.ScriptFromFile("/Staking/get_farm_meta").Args(o.Arguments().UInt64(farmID)).RunMarshalAs(&farmMeta)
	if err != nil {
		panic(err)
	}
	// assert.Equal(t, farmMeta.id, uint64(0))
	// assert.Equal(t, farmMeta.totalStaked, float64(0))
	// assert.Equal(t, farmMeta.rewardTokensPerSecondByID, struct{ uint64 float64 }{uint64: 0})
	// assert.Equal(t, farmMeta.lastRewardTimestamp, float64(0))
}

func TestStake(t *testing.T) {
	o := overflow.NewTestingEmulator().Start()
	setupFUSDVaultWithBalance(o, "account", 1000.0)

	flowAmount := 100.0
	fusdAmount := 150.0
	flowStoragePath := "flowTokenVault"
	fusdStoragePath := "fusdVault"

	testCreateSwapPool(o, t, flowStoragePath, flowAmount, fusdStoragePath, fusdAmount)

	farmID := uint64(0)
	testCreateNewFarm(o, t, farmID)

	lpAmount := 0.1
	testFirstStake(o, t, "account", farmID, lpAmount)
	testStake(o, t, "account", farmID, lpAmount)
}

func testFirstStake(o *overflow.Overflow, t *testing.T,
	account string,
	farmID uint64,
	amountToStake float64) {

	// get Farm to see how much already staked
	farmMeta := &FarmMeta{}
	err := o.ScriptFromFile("/Staking/get_farm_meta").Args(o.Arguments().UInt64(farmID)).RunMarshalAs(&farmMeta)
	if err != nil {
		panic(err)
	}
	assert.NotEqual(t, farmMeta.TotalStaked, json.Number("0.0"))

	totalStaked, err := farmMeta.TotalStaked.Float64()
	if err != nil {
		panic(err)
	}

	FARM_ID := fmt.Sprintf("%d", farmID)
	AMOUNT_STAKED := fmt.Sprintf("%.8f", amountToStake)
	TOTAL_STAKED := fmt.Sprintf("%.8f", amountToStake+totalStaked)
	SIGNER_ADDRESS := "0x" + o.Account(account).Address().String()

	o.TransactionFromFile("/Staking/user/stake").SignProposeAndPayAs(account).
		Args(o.
			Arguments().
			UInt64(farmID).
			UFix64(amountToStake)).
		Test(t).
		AssertSuccess().
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.TokensWithdrawn", map[string]interface{}{
			"amount":  AMOUNT_STAKED,
			"from":    SIGNER_ADDRESS,
			"tokenID": FARM_ID,
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.TokensDeposited", map[string]interface{}{
			"amount":  AMOUNT_STAKED,
			"to":      "", // blank only on first stake as controller is yet to be deposited in callers collections
			"tokenID": FARM_ID,
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.StakingRewards.TokensStaked", map[string]interface{}{
			"address":      SIGNER_ADDRESS,
			"poolID":       FARM_ID,
			"amountStaked": AMOUNT_STAKED,
			"totalStaked":  TOTAL_STAKED,
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.StakingRewards.StakingControllerDeposited", map[string]interface{}{
			"farmID": FARM_ID,
			"to":     SIGNER_ADDRESS,
		})).
		AssertEventCount(4)

	err = o.ScriptFromFile("/Staking/get_farm_meta").Args(o.Arguments().UInt64(farmID)).RunMarshalAs(&farmMeta)
	if err != nil {
		panic(err)
	}
	assert.Equal(t, farmMeta.Id, json.Number("0"))
	assert.Equal(t, farmMeta.TotalStaked, json.Number(TOTAL_STAKED))
	// assert.Equal(t, farmMeta.RewardTokensPerSecondByID, struct{ uint64 float64 }{uint64: 0})
	// assert.Equal(t, farmMeta.LastRewardTimestamp, float64(0))
}

func testStake(o *overflow.Overflow, t *testing.T,
	account string,
	farmID uint64,
	amountToStake float64) {

	// get Farm to see how much already staked
	farmMeta := &FarmMeta{}
	err := o.ScriptFromFile("/Staking/get_farm_meta").Args(o.Arguments().UInt64(farmID)).RunMarshalAs(&farmMeta)
	// json := o.ScriptFromFile("/Staking/get_farm_meta").Args(o.Arguments().UInt64(farmID)).RunReturnsJsonString()
	// panic(json)
	if err != nil {
		panic(err)
	}
	// alreadyStaked, _ := farmMeta.totalStaked.Float64()

	// assert.NotEqual(t, alreadyStaked, 0.0)

	totalStaked, err := farmMeta.TotalStaked.Float64()
	if err != nil {
		panic(err)
	}

	FARM_ID := fmt.Sprintf("%d", farmID)
	AMOUNT_STAKED := fmt.Sprintf("%.8f", amountToStake)
	// TOTAL_STAKED := fmt.Sprintf("%.8f", amountToStake)
	TOTAL_STAKED := fmt.Sprintf("%.8f", amountToStake+totalStaked)
	SIGNER_ADDRESS := "0x" + o.Account(account).Address().String()

	o.TransactionFromFile("/Staking/user/stake").SignProposeAndPayAs(account).
		Args(o.
			Arguments().
			UInt64(farmID).
			UFix64(amountToStake)).
		Test(t).
		AssertSuccess().
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.TokensWithdrawn", map[string]interface{}{
			"amount":  AMOUNT_STAKED,
			"from":    SIGNER_ADDRESS,
			"tokenID": FARM_ID,
		})).
		// AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.TokensDeposited", map[string]interface{}{
		// 	"amount":  AMOUNT_STAKED,
		// 	"to":      "", // blank only on first stake as controller is yet to be deposited in callers collections
		// 	"tokenID": FARM_ID,
		// })).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.StakingRewards.TokensStaked", map[string]interface{}{
			"address":      SIGNER_ADDRESS,
			"poolID":       FARM_ID,
			"amountStaked": AMOUNT_STAKED,
			"totalStaked":  TOTAL_STAKED,
		})).
		AssertEventCount(3) // -1 if user already has stake controller

	err = o.ScriptFromFile("/Staking/get_farm_meta").Args(o.Arguments().UInt64(farmID)).RunMarshalAs(&farmMeta)
	if err != nil {
		panic(err)
	}
	assert.Equal(t, farmMeta.Id, json.Number("0"))
	// assert.Equal(t, farmMeta.TotalStaked, float64(0))
	// assert.Equal(t, farmMeta.rewardTokensPerSecondByID, struct{ uint64 float64 }{uint64: 0})
	// assert.Equal(t, farmMeta.LastRewardTimestamp, float64(0))
}

func TestClaimRewards(t *testing.T) {
	o := overflow.NewTestingEmulator().Start()
	setupFUSDVaultWithBalance(o, "account", 1000.0)

	flowAmount := 100.0
	fusdAmount := 150.0
	flowStoragePath := "flowTokenVault"
	fusdStoragePath := "fusdVault"

	// Create EmuSwap Pool
	testCreateSwapPool(o, t, flowStoragePath, flowAmount, fusdStoragePath, fusdAmount)

	farmID := uint64(0)
	testCreateNewFarm(o, t, farmID)
	// testCreateRewardPool(o, t, "flowTokenVault", 100.0)
	// testAddLiquidityAndStake(o, t, "account", 0, flowAmount, fusdAmount)
	toggleMockTime(o, t)
	updateMockTimestamp(o, t, 1.0)

	lpAmount := 1.0
	testFirstStake(o, t, "account", farmID, lpAmount/2)
	// testStake(o, t, "account", farmID, lpAmount/2)

	updateMockTimestamp(o, t, 3.0) // event though we sleep we need to send a tx to bump the current block

	claimRewards(o, t, "account", farmID)
}

func claimRewards(o *overflow.Overflow, t *testing.T,
	account string,

	farmID uint64) float64 {

	// time.Sleep(5 * time.Second)

	// Get pending Rewards for expected amount
	pendingRewards := map[string]json.Number{}
	err := o.ScriptFromFile("/Staking/get_pending_rewards").Args(o.Arguments().UInt64(farmID).Address(account)).RunMarshalAs(&pendingRewards)
	if err != nil {
		panic(err)
	}
	expectedAmount, _ := pendingRewards["0"].Float64()

	// get farm meta for total remaining
	farmMeta := &FarmMeta{}
	err = o.ScriptFromFile("/Staking/get_farm_meta").Args(o.Arguments().UInt64(farmID)).RunMarshalAs(&farmMeta)
	if err != nil {
		panic(err)
	}
	assert.NotNil(t, farmMeta.LastRewardTimestamp)
	rewardsRemaining, _ := farmMeta.RewardsRemainingByID["0"].Float64()

	// j00lz populate reward debt with users current reward debt
	type StakeMeta struct {
		Address        string
		Balance        json.Number
		RewardDebtByID map[string]json.Number
		PendingRewards map[string]json.Number
	}
	stakeMeta := &StakeMeta{}
	err = o.ScriptFromFile("/Staking/get_stake_meta").Args(o.Arguments().UInt64(farmID).Account(account)).RunMarshalAs(&stakeMeta)
	if err != nil {
		panic(err)
	}
	// assert.Equal(t, stakeMeta, "")
	rewardDebt, _ := stakeMeta.RewardDebtByID["0"].Float64()

	// FARM_ID := fmt.Sprintf("%d", farmID)
	EXPECTED_AMOUNT := fmt.Sprintf("%.8f", expectedAmount)
	EXPECTED_REMAINING := fmt.Sprintf("%.8f", rewardsRemaining-expectedAmount)
	EXPECTED_REWARD_DEBT := fmt.Sprintf("%.8f", rewardDebt+expectedAmount)
	// createNewFarm(o, t, 0)

	CONTRACT_ADDRESS := "0x" + o.Account("account").Address().String()
	SIGNER_ADDRESS := "0x" + o.Account(account).Address().String()

	o.TransactionFromFile("/Staking/user/claim_rewards").SignProposeAndPayAs(account).
		Args(o.
			Arguments().
			UInt64(farmID)).
		Test(t).
		AssertSuccess().
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuToken.TokensWithdrawn", map[string]interface{}{
			"amount": EXPECTED_AMOUNT,
			"from":   CONTRACT_ADDRESS,
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuToken.TokensDeposited", map[string]interface{}{
			"amount": EXPECTED_AMOUNT,
			"to":     SIGNER_ADDRESS,
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.StakingRewards.RewardsClaimed", map[string]interface{}{
			"address":        SIGNER_ADDRESS,
			"amountClaimed":  EXPECTED_AMOUNT,
			"rewardDebt":     EXPECTED_REWARD_DEBT,
			"tokenType":      "A.f8d6e0586b0a20c7.EmuToken.Vault",
			"totalRemaining": EXPECTED_REMAINING,
		})).
		AssertEventCount(3)

	return roundFloat(expectedAmount)
}

func getPendingRewards(o *overflow.Overflow) {
	o.ScriptFromFile("staking/get_pending_rewards")
}

func roundFloat(x float64) float64 {
	return math.Floor(x*100000000) / 100000000
}

func TestStory2EqualStakesShareEqualRewards(t *testing.T) {
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

	toggleMockTime(o, t)
	updateMockTimestamp(o, t, 1.0)

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
	assert.Equal(t, user1Claimed/roundFloat(user2Claimed/factor), 1.0)
	// assert.Equal(t, user2Claimed/roundFloat(user1Claimed/factor), 0.0)
	// assert.Equal(t, user1Claimed-roundFloat(user2Claimed/factor), 0.0)
}

func TestAddRewardReceiver(t *testing.T) {
	o := overflow.NewTestingEmulator().Start()

	setupFUSDVaultWithBalance(o, "account", 100.0)
	testCreateSwapPool(o, t, "flowTokenVault", 100.0, "fusdVault", 100.0)

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

type StakesInfo struct {
	Stakes map[string]StakeInfo
}

type StakeInfo struct {
	Address        string
	Balance        json.Number
	PendingRewards map[uint64]float64
	RewardDebtByID map[uint64]float64
}
