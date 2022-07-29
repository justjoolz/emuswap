package main

import (
	"encoding/json"
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

	testCreateSwapPool(o, t, token1StorageID, token1Amount, token2StorageID, token2Amount)
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

	TOKEN_1_TYPE := storagePathToTokenIdentifier(token1StorageID)
	TOKEN_2_TYPE := storagePathToTokenIdentifier(token2StorageID)

	poolID := getPoolIDFromTokenIDs(o, token1StorageID, token2StorageID)
	// totalPoolLiquidity := 0.0

	TOKEN_1_AMOUNT := fmt.Sprintf("%.8f", token1Amount)
	TOKEN_2_AMOUNT := fmt.Sprintf("%.8f", token2Amount)
	// CONTRACT_ADDRESS := "0x" + o.Account("account").Address().String()
	SIGNER_ADDRESS := "0x" + o.Account(signer).Address().String()

	TOKEN_ID := fmt.Sprintf("%d", poolID)

	o.TransactionFromFile("/EmuSwap/user/add_liquidity").SignProposeAndPayAs(signer).
		Args(o.
			Arguments().
			String(token1StorageID).
			UFix64(token1Amount).
			String(token2StorageID).
			UFix64(token2Amount)).
		Test(t).
		AssertSuccess().
		AssertEmitEvent(overflow.NewTestEvent(TOKEN_1_TYPE+".TokensWithdrawn", map[string]interface{}{
			"amount": TOKEN_1_AMOUNT,
			"from":   SIGNER_ADDRESS,
		})).
		AssertEmitEvent(overflow.NewTestEvent(TOKEN_2_TYPE+".TokensWithdrawn", map[string]interface{}{
			"amount": TOKEN_2_AMOUNT,
			"from":   SIGNER_ADDRESS,
		})).
		AssertEmitEvent(overflow.NewTestEvent(TOKEN_1_TYPE+".TokensWithdrawn", map[string]interface{}{
			"amount": TOKEN_1_AMOUNT,
			"from":   "",
		})).
		AssertEmitEvent(overflow.NewTestEvent(TOKEN_2_TYPE+".TokensWithdrawn", map[string]interface{}{
			"amount": TOKEN_2_AMOUNT,
			"from":   "",
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.TokensMinted", map[string]interface{}{
			"amount":  "1.00000000", // j00lz 1.00000000 is hardcoded... need to calculate value in advance based on lpAmount provided vs totalPoolLiquidity
			"tokenID": TOKEN_ID,
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.TokensDeposited", map[string]interface{}{
			"amount":  "1.00000000",
			"to":      SIGNER_ADDRESS,
			"tokenID": TOKEN_ID,
		})).
		AssertEventCount(8)
}

func TestRemoveLiquidity(t *testing.T) {
	o := overflow.NewTestingEmulator().Start()

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
	addLiquidity(o, t, "account", token1StorageID, token1Amount, token2StorageID, token2Amount)
	addLiquidity(o, t, "user1", token1StorageID, token1Amount, token2StorageID, token2Amount)
	amount := 0.1
	removeLiquidity(o, t, "user1", amount, token1StorageID, token2StorageID)
	removeLiquidity(o, t, "account", amount, token1StorageID, token2StorageID)
}

func removeLiquidity(
	o *overflow.Overflow,
	t *testing.T,
	signer string,

	amount float64,
	token1StorageID string,
	token2StorageID string,
) {
	poolID := getPoolIDfromTokenIDs(o, storagePathToTokenIdentifier(token1StorageID), storagePathToTokenIdentifier(token2StorageID))
	poolMeta := getPoolMeta(o, poolID)

	// totalSupply, _ := getPoolMeta(o, poolID).TotalSupply.Float64()
	totalSupply := getSupplyByID(o, poolID)

	precision := 10000.0 // inaccuracy?
	liquidityPercentage := roundFloat(roundFloat(amount*precision) / roundFloat(totalSupply))

	// SUPPLY := fmt.Sprintf("%.8f", totalSupply)
	// LIQUIDITY_PERCENTAGE := fmt.Sprintf("%.8f", liquidityPercentage)
	// AMOUNT := fmt.Sprintf("%.8f", amount)

	token1Amount, _ := poolMeta.Token1Amount.Float64()
	token2Amount, _ := poolMeta.Token2Amount.Float64()

	TOKEN_1_AMOUNT := fmt.Sprintf("%.8f", roundFloat((roundFloat(token1Amount)*liquidityPercentage)/precision))
	TOKEN_2_AMOUNT := fmt.Sprintf("%.8f", roundFloat((roundFloat(token2Amount)*liquidityPercentage)/precision))

	TOKEN_1_TYPE := storagePathToTokenIdentifier(token1StorageID)
	TOKEN_2_TYPE := storagePathToTokenIdentifier(token2StorageID)

	TOKEN_AMOUNT := fmt.Sprintf("%.8f", amount)

	SIGNER_ADDRESS := "0x" + o.Account(signer).Address().String()
	CONTRACT_ADDRESS := "0x" + o.Account("account").Address().String()

	TOKEN_ID := fmt.Sprintf("%d", 0) // (token1StorageID, token2StorageID)

	o.TransactionFromFile("/EmuSwap/user/remove_liquidity").SignProposeAndPayAs(signer).
		Args(o.
			Arguments().
			UFix64(amount).
			String(token1StorageID).
			String(token2StorageID)).
		Test(t).
		AssertSuccess().
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.TokensWithdrawn", map[string]interface{}{
			"amount":  TOKEN_AMOUNT,
			"from":    SIGNER_ADDRESS,
			"tokenID": TOKEN_ID,
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.TokensBurned", map[string]interface{}{
			"amount":  TOKEN_AMOUNT,
			"tokenID": TOKEN_ID,
		})).
		// AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.DebugMath", map[string]interface{}{
		// 	"a":                   TOKEN_1_AMOUNT,
		// 	"b":                   TOKEN_2_AMOUNT,
		// 	"balance":             AMOUNT,
		// 	"liquidityPercentage": LIQUIDITY_PERCENTAGE,
		// 	"supply":              SUPPLY,
		// })).
		AssertEmitEvent(overflow.NewTestEvent(TOKEN_1_TYPE+".TokensWithdrawn", map[string]interface{}{
			"amount": TOKEN_1_AMOUNT,
			"from":   CONTRACT_ADDRESS,
		})).
		AssertEmitEvent(overflow.NewTestEvent(TOKEN_2_TYPE+".TokensWithdrawn", map[string]interface{}{
			"amount": TOKEN_2_AMOUNT,
			"from":   CONTRACT_ADDRESS,
		})).
		AssertEmitEvent(overflow.NewTestEvent(TOKEN_1_TYPE+".TokensWithdrawn", map[string]interface{}{
			"amount": TOKEN_1_AMOUNT,
			"from":   "",
		})).
		AssertEmitEvent(overflow.NewTestEvent(TOKEN_1_TYPE+".TokensDeposited", map[string]interface{}{
			"amount": TOKEN_1_AMOUNT,
			"to":     SIGNER_ADDRESS,
		})).
		AssertEmitEvent(overflow.NewTestEvent(TOKEN_2_TYPE+".TokensWithdrawn", map[string]interface{}{
			"amount": TOKEN_2_AMOUNT,
			"from":   "",
		})).
		AssertEmitEvent(overflow.NewTestEvent(TOKEN_2_TYPE+".TokensDeposited", map[string]interface{}{
			"amount": TOKEN_2_AMOUNT,
			"to":     SIGNER_ADDRESS,
		})).
		AssertEventCount(8)

}

func TestSwap(t *testing.T) {
	o := overflow.NewTestingEmulator().Start()

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
	amount := 0.1

	signer := "user1"

	testSwap(o, t, signer, token1StorageID, token2StorageID, amount)
	testSwap(o, t, signer, token2StorageID, token1StorageID, amount/2)
}

func testSwap(
	o *overflow.Overflow,
	t *testing.T,
	signer string,

	fromTokenStorageIdentifier string,
	toTokenStorageIdentifier string,
	amount float64,
) {
	fmt.Println("~~~~~~~~~~~~~~~~~~!")
	fmt.Println("| TESTING SWAP!!! |")
	fmt.Println("~~~~~~~~~~~~~~~~~~!")
	fmt.Println(" from " + fromTokenStorageIdentifier)
	fmt.Println(" to   " + toTokenStorageIdentifier)

	daoFee := getDAOFeePercentage(o)
	lpFee := getLPFeePercentage(o)

	poolID := getPoolIDfromTokenIDs(o, storagePathToTokenIdentifier(fromTokenStorageIdentifier), storagePathToTokenIdentifier(toTokenStorageIdentifier))
	SIDE := getSide(o, storagePathToTokenIdentifier(fromTokenStorageIdentifier), storagePathToTokenIdentifier(toTokenStorageIdentifier))
	fmt.Println(" Pool ID: " + fmt.Sprint(poolID) + " Side " + SIDE)

	amountAfterFee := (1 - daoFee - lpFee) * amount

	expectedB := float64(0)
	TOKEN_1_KEY := ""
	TOKEN_2_KEY := ""
	if SIDE == "1" {
		expectedB = getQuoteExactAtoB(o, poolID, amountAfterFee)
		TOKEN_1_KEY = "token1Amount"
		TOKEN_2_KEY = "token2Amount"
	} else {
		expectedB = getQuoteExactBtoA(o, poolID, amountAfterFee)
		TOKEN_1_KEY = "token2Amount"
		TOKEN_2_KEY = "token1Amount"
	}

	EXPECTED_TOKEN_AMOUNT_RETURNED := fmt.Sprintf("%.8f", expectedB)

	// if fromTokenStorageIdentifier == "fusdVault" && toTokenStorageIdentifier == "emuTokenVault" {
	// if toTokenStorageIdentifier == "emuTokenVault" {
	// 	fmt.Println(getSide(o, fromTokenStorageIdentifier, toTokenStorageIdentifier))
	// 	panic(poolID)
	// }
	// totalFee := (daoFee + lpFee) * amount
	// let token1Amount = originalBalance * (1.0 - self.LPFeePercentage - self.DAOFeePercentage)
	// let token2Amount = self.quoteSwapExactToken1ForToken2(amount: token1Amount)
	// quotes := getQuotes(o, poolID, amount)

	// afterFees := amount * (1.0 - lpFee - daoFee)
	SIGNER_ADDRESS := "0x" + o.Account(signer).Address().String()
	CONTRACT_ADDRESS := "0x" + o.Account("account").Address().String()

	TOKEN_AMOUNT := fmt.Sprintf("%.8f", amount)
	MINUS_DAO_FEE := fmt.Sprintf("%.8f", (1-daoFee)*amount)
	DAO_FEE_AMOUNT := fmt.Sprintf("%.8f", daoFee*amount)
	// TOTAL_FEE_AMOUNT := fmt.Sprintf("%.8f", (lpFee+daoFee)*amount)
	FEE_TOKEN := storagePathToTokenIdentifier(fromTokenStorageIdentifier) + ".Vault"
	AMOUNT_AFTER_FEE := fmt.Sprintf("%.8f", roundFloat(roundFloat(1-daoFee-lpFee)*amount))

	// TOKEN_ID := fmt.Sprintf("%d", 0) // (token1StorageID, token2StorageID)

	TOKEN_IDENTIFIER_A := storagePathToTokenIdentifier(fromTokenStorageIdentifier)
	TOKEN_IDENTIFIER_B := storagePathToTokenIdentifier(toTokenStorageIdentifier)

	o.TransactionFromFile("EmuSwap/user/swap").SignProposeAndPayAs(signer).
		Args(o.
			Arguments().
			String(fromTokenStorageIdentifier).
			String(toTokenStorageIdentifier).
			UFix64(amount)).
		Test(t).
		AssertSuccess().
		// AssertEventCount(7). // 7 events if never collected fee before 8 if already have this fee type (this because we move <- whole fee deducted vault in first time and deposit into that thereafter) j00lz note
		AssertEmitEvent(overflow.NewTestEvent(TOKEN_IDENTIFIER_A+".TokensWithdrawn", map[string]interface{}{
			"amount": TOKEN_AMOUNT,
			"from":   SIGNER_ADDRESS,
		})).
		AssertEmitEvent(overflow.NewTestEvent(TOKEN_IDENTIFIER_A+".TokensWithdrawn", map[string]interface{}{
			"amount": DAO_FEE_AMOUNT,
			"from":   "",
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.FeesDeposited", map[string]interface{}{
			"amount":          DAO_FEE_AMOUNT,
			"tokenIdentifier": FEE_TOKEN,
		})).
		AssertEmitEvent(overflow.NewTestEvent(TOKEN_IDENTIFIER_A+".TokensDeposited", map[string]interface{}{
			"amount": MINUS_DAO_FEE,
			"to":     CONTRACT_ADDRESS,
		})).
		AssertEmitEvent(overflow.NewTestEvent("A.f8d6e0586b0a20c7.EmuSwap.Trade", map[string]interface{}{
			"side":      SIDE,
			TOKEN_1_KEY: AMOUNT_AFTER_FEE,
			TOKEN_2_KEY: EXPECTED_TOKEN_AMOUNT_RETURNED,
		})).
		AssertEmitEvent(overflow.NewTestEvent(TOKEN_IDENTIFIER_B+".TokensWithdrawn", map[string]interface{}{
			"amount": EXPECTED_TOKEN_AMOUNT_RETURNED,
			"from":   CONTRACT_ADDRESS,
		})).
		AssertEmitEvent(overflow.NewTestEvent(TOKEN_IDENTIFIER_B+".TokensDeposited", map[string]interface{}{
			"amount": EXPECTED_TOKEN_AMOUNT_RETURNED,
			"to":     SIGNER_ADDRESS,
		}))
}

func getDAOFeePercentage(o *overflow.Overflow) float64 {
	var value json.Number
	err := o.ScriptFromFile("get_dao_fee_percentage").RunMarshalAs(&value)
	if err != nil {
		panic(err)
	}
	fee, _ := value.Float64()
	return fee
}

func getLPFeePercentage(o *overflow.Overflow) float64 {
	var fee json.Number
	o.ScriptFromFile("get_lp_fee_percentage").RunMarshalAs(&fee)
	result, _ := fee.Float64()
	return result
}

func getPoolIDFromTokenIDs(o *overflow.Overflow, tokenID1 string, tokenID2 string) uint64 {
	var poolID json.Number
	fmt.Println(tokenID1)
	fmt.Println(tokenID2)
	o.ScriptFromFile("/Staking/get_pool_id_from_token_ids").Args(o.Arguments().String(tokenID1).String(tokenID2)).RunMarshalAs(&poolID)
	// data := o.ScriptFromFile("/Staking/get_pool_id_from_token_ids").Args(o.Arguments().String(tokenID1).String(tokenID2)).RunReturnsJsonString()
	// fmt.Println(data)
	fmt.Println(poolID)
	id, err := poolID.Int64()
	if err != nil {
		// panic(err)
	}
	fmt.Println(id)
	return uint64(id)
}

func getNextPoolID(o *overflow.Overflow) uint64 {
	return uint64(len(getPoolIDs(o)))
}

func getPoolIDs(o *overflow.Overflow) []string {
	var poolIDs []string
	err := o.ScriptFromFile("/get_pool_ids").RunMarshalAs(&poolIDs)
	if err != nil {
		panic(err)
	}
	fmt.Println(poolIDs)
	// o.ScriptFromFile("/Staking/get_pool_id_from_token_ids").RunMarshalAs(&poolIDs)
	// fmt.Print(o.ScriptFromFile("/Staking/get_pool_id_from_token_ids").RunReturnsJsonString())
	return poolIDs
}

type PoolMeta struct {
	Token1Amount     json.Number
	Token2Amount     json.Number
	Token1Identifier string
	Token2Identifier string
	TotalSupply      json.Number
}

func getPoolMeta(o *overflow.Overflow, poolID uint64) *PoolMeta {
	poolMeta := &PoolMeta{}
	err := o.ScriptFromFile("get_pool_meta").Args(o.Arguments().UInt64(poolID)).RunMarshalAs(&poolMeta)
	if err != nil {
		panic(err)
	}
	return poolMeta
}

func getSupplyByID(o *overflow.Overflow, poolID uint64) float64 {
	r, err := getPoolMeta(o, poolID).TotalSupply.Float64()
	if err != nil {
		panic(err)
	}
	return r
}

func getPooslMeta(o *overflow.Overflow) *[]PoolMeta {
	poolsMeta := &[]PoolMeta{}
	o.ScriptFromFile("/Staking/get_pools_meta").RunMarshalAs(&poolsMeta)
	return poolsMeta
}

func getSwapsAvailable(o *overflow.Overflow, tokenIdentifier string) map[string]uint64 {
	var swapsAvailable map[string]uint64
	o.ScriptFromFile("/Staking/get_swaps_available").Args(o.Arguments().String(tokenIdentifier)).RunMarshalAs(&swapsAvailable)
	return swapsAvailable
}

func getQuotes(o *overflow.Overflow, poolID uint64, amount float64) map[string]float64 {
	quotes := map[string]float64{}
	o.ScriptFromFile("/pool/get_quotes").Args(o.Arguments().UInt64(poolID).UFix64(amount)).RunMarshalAs(&quotes)
	return quotes
}

func getQuoteAtoExactB(o *overflow.Overflow, poolID uint64, amount float64) float64 {
	var quote json.Number
	o.ScriptFromFile("/pool/get_quote_a_to_exact_b").Args(o.Arguments().UInt64(poolID).UFix64(amount)).RunMarshalAs(&quote)
	r, _ := quote.Float64()
	return r
}

func getQuoteBtoExactA(o *overflow.Overflow, poolID uint64, amount float64) float64 {
	var quote json.Number
	o.ScriptFromFile("/pool/get_quote_b_to_exact_a").Args(o.Arguments().UInt64(poolID).UFix64(amount)).RunMarshalAs(&quote)
	r, _ := quote.Float64()
	return r
}

func getQuoteExactAtoB(o *overflow.Overflow, poolID uint64, amount float64) float64 {
	var quote json.Number
	o.ScriptFromFile("/pool/get_quote_exact_a_to_b").Args(o.Arguments().UInt64(poolID).UFix64(amount)).RunMarshalAs(&quote)
	result, _ := quote.Float64()
	return result
}

func getQuoteExactBtoA(o *overflow.Overflow, poolID uint64, amount float64) float64 {
	var quote json.Number
	o.ScriptFromFile("/pool/get_quote_exact_b_to_a").Args(o.Arguments().UInt64(poolID).UFix64(amount)).RunMarshalAs(&quote)
	r, _ := quote.Float64()
	return r
}

func getPoolIDfromTokenIDs(o *overflow.Overflow, token1identifier string, token2identifier string) uint64 {
	var poolID json.Number
	err := o.ScriptFromFile("get_pool_id_from_token_ids").Args(o.Arguments().String(token1identifier).String(token2identifier)).RunMarshalAs(&poolID)
	if err != nil {
		panic(err)
	}
	r, _ := poolID.Int64()
	// fmt.Println("------------> " + token1identifier + " -----> " + token2identifier + " ----> " + fmt.Sprint(r))
	return uint64(r)
}

func getSide(o *overflow.Overflow, fromTokenIdentifier string, toTokenIdentifier string) string {
	poolID := getPoolIDfromTokenIDs(o, (fromTokenIdentifier), (toTokenIdentifier))
	meta := getPoolMeta(o, poolID)
	r := ""

	fmt.Println("getSide()")
	fmt.Println(poolID)
	fmt.Println(meta)
	fmt.Println(fromTokenIdentifier)
	fmt.Println(toTokenIdentifier)
	fmt.Println(meta.Token1Identifier)
	fmt.Println(meta.Token2Identifier)

	if fromTokenIdentifier+".Vault" == meta.Token1Identifier {
		r = "1"
	} else if toTokenIdentifier+".Vault" == meta.Token1Identifier {
		r = "2"
	}
	return r
}

func readFeesCollected(o *overflow.Overflow) map[string]json.Number {
	var feesCollected map[string]json.Number
	o.ScriptFromFile("read_fees_collected").RunMarshalAs(&feesCollected)
	return feesCollected
}
