package main

import (
	"encoding/json"
	"fmt"
	"testing"

	"github.com/bjartek/overflow/overflow"
	"github.com/stretchr/testify/assert"
)

func TestCreateNewFarm(t *testing.T) {
	o := overflow.NewTestingEmulator().Start()
	setupFUSDVaultWithBalance(o, "account", 1000.0)

	flowAmount := 100.0
	fusdAmount := 150.0
	flowStoragePath := "flowTokenVault"
	fusdStoragePath := "fusdVault"

	testCreatePool(o, t, flowStoragePath, flowAmount, fusdStoragePath, fusdAmount)

	farmID := uint64(0)
	// SIGNER_ADDRESS := "0xf8d6e0586b0a20c7"

	testCreateNewFarm(o, t, 0)

	testCreateRewardPool(o, t, "fusdVault", 100.0)

	farmMeta := &FarmMeta{}
	err := o.ScriptFromFile("/Staking/get_farm_meta").Args(o.Arguments().UInt64(0)).RunMarshalAs(&farmMeta)
	if err != nil {
		panic(err)
	}
	assert.Equal(t, farmMeta.Id, json.Number("0"))
	assert.Equal(t, farmMeta.TotalStaked, json.Number("0.00000000"))
	// assert.Equal(t, farmMeta.Stakes, "")
	// assert.Equal(t, farmMeta.RewardTokensPerSecondByID, "")

	/*
		"A.f8d6e0586b0a20c7.StakingRewards.FarmMeta(
			id: 0,
			stakes: {},
			totalStaked: 0.00000000,
			lastRewardTimestamp: 1655367585.00000000,
			farmWeightsByID: {0: 1.00000000, 1: 1.00000000},
			rewardTokensPerSecondByID: {0: 1.00000000, 1: 1.00000000},
			totalAccumulatedTokensPerShareByID: {1: 0.00000000, 0: 0.00000000})")
	*/

	// no pending rewards
	pendingRewards := o.ScriptFromFile("/Staking/get_pending_rewards").Args(o.Arguments().UInt64(farmID).Account("account")).RunReturnsJsonString() //  .RunMarshalAs(&farmMeta)
	assert.Equal(t, pendingRewards, string("{}"))

	// no Stakes
	stakeInfo := o.ScriptFromFile("/Staking/read_stakes_info").Args(o.Arguments().UInt64(farmID)).RunReturnsJsonString() // .RunMarshalAs(&farmMeta)
	assert.Equal(t, stakeInfo, string("{}"))

}

func testCreateNewFarm(o *overflow.Overflow, t *testing.T, farmID uint64) {
	FARM_ID := fmt.Sprintf("%d", farmID)
	o.TransactionFromFile("/Staking/admin/create_new_farm").SignProposeAndPayAs("account").
		Args(o.
			Arguments().
			UInt64(farmID)).
		Test(t).
		AssertSuccess().
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.StakingRewards.NewFarmCreated", map[string]interface{}{
			"farmID": FARM_ID,
		})).
		AssertEventCount(1)
}

func TestCreateRewardPool(t *testing.T) {
	o := overflow.NewTestingEmulator().Start()
	setupFUSDVaultWithBalance(o, "account", 1000.0)

	vaultIdentifier := "flowTokenVault"
	amount := 100000.0

	testCreateRewardPool(o, t, vaultIdentifier, amount)
}

func testCreateRewardPool(o *overflow.Overflow, t *testing.T,
	vaultIdentifier string,
	amount float64) {

	nftsAccepted := []string{} // []string{"ExampleNFTCollection", "ExampleNFT2Collection"}

	o.ScriptFromFile("")
	o.TransactionFromFile("/Staking/admin/create_reward_pool").SignProposeAndPayAs("account").
		Args(o.
			Arguments().
			String(vaultIdentifier).
			UFix64(amount).
			StringArray(nftsAccepted...)).
		Test(t).
		AssertSuccess().
		// AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.FUSD.TokensWithdrawn", map[string]interface{}{
		// 	"amount": "100.00000000",
		// 	"from":   "0xf8d6e0586b0a20c7",
		// })).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.StakingRewards.RewardPoolCreated", map[string]interface{}{
			"id": "1",
		})).
		AssertEventCount(2)

}

func TestUpdateMockTimestamp(t *testing.T) {
	o := overflow.NewTestingEmulator().Start()
	setupFUSDVaultWithBalance(o, "account", 1000.0)
	updateMockTimestamp(o, t, 100.0)
}

func updateMockTimestamp(o *overflow.Overflow, t *testing.T, delta float64) {
	o.TransactionFromFile("/Staking/admin/update_mock_timestamp").SignProposeAndPayAs("account").
		Args(o.
			Arguments().
			UFix64(delta)).
		Test(t).
		AssertSuccess()
}

func TestToggleMockTime(t *testing.T) {
	o := overflow.NewTestingEmulator().Start()
	setupFUSDVaultWithBalance(o, "account", 1000.0)
	toggleMockTime(o, t)
	updateMockTimestamp(o, t, 100.0)
}

func toggleMockTime(o *overflow.Overflow, t *testing.T) {
	o.TransactionFromFile("/Staking/admin/toggle_mock_time").SignProposeAndPayAs("account").
		Test(t).
		AssertSuccess()
}

type FarmMeta struct {
	FarmWeightsByID struct {
		uint64 float64
	}
	Id                                 json.Number
	LastRewardTimestamp                json.Number
	RewardTokensPerSecondByID          map[string]json.Number
	Stakes                             map[string]Stake
	TotalAccumulatedTokensPerShareByID map[string]json.Number
	TotalStaked                        json.Number
	RewardsRemainingByID               map[string]json.Number
}

type Stake struct {
	Address        string
	Balance        json.Number
	PendingRewards map[string]json.Number
	RewardDebtByID map[string]json.Number
}
