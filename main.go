package main

import (
	"fmt"

	"github.com/bjartek/overflow/overflow"
)

func mintFlowTokens(o *overflow.Overflow, account string, amount float64) {
	o.TransactionFromFile("demo/mintFlowTokens").
		SignProposeAndPayAs("account").
		Args(o.Arguments().
			UFix64(amount).
			Account(account)).
		RunGetEventsWithNameOrError("Minted")
	// RunPrintEventsFull()
}

func setupFUSDVaultWithBalance(o *overflow.Overflow, account string, amount float64) {
	o.TransactionFromFile("FUSD/setup").SignProposeAndPayAs(account).RunGetEventsWithNameOrError("") //.RunPrintEventsFull()
	o.TransactionFromFile("demo/mintFUSD").SignProposeAndPayAs("account").Args(o.Arguments().UFix64(amount).Address(account)).RunGetEventsWithNameOrError("")
}

func createPoolFlowFUSD(o *overflow.Overflow, account string, flowAmount float64, fusdAmount float64) {
	o.TransactionFromFile("EmuSwap/admin/create_new_pool_FLOW_FUSD").
		SignProposeAndPayAs("account").
		Args(o.
			Arguments().
			UFix64(flowAmount).
			UFix64(fusdAmount)).
		RunPrintEventsFull()
}

func main() {
	o := overflow.NewOverflow().Start()
	fmt.Printf("%v", o.State.Accounts())

	// flow transactions send "./transactions/EmuSwap/admin/create_new_pool_FLOW_FUSD.cdc" 100.0 500.0 --signer "admin-account"
	//o.TransactionFromFile("EmuSwap/admin/create_new_pool_FLOW_FUSD").SignProposeAndPayAs("account").NamedArguments(map[string]string{"token1": "100.0", "token2": "500.0"}).RunPrintEventsFull()

	fmt.Print("Minting Flow Tokens")

	mintFlowTokens(o, "account", 1000.0)
	mintFlowTokens(o, "user1", 1000.0)
	mintFlowTokens(o, "user2", 1000.0)

	// Setup FUSD Vaults
	setupFUSDVaultWithBalance(o, "account", 111111.1)
	setupFUSDVaultWithBalance(o, "user1", 1000.1)
	setupFUSDVaultWithBalance(o, "user2", 1000.1)
	// EmuSwap tests
	//

	fmt.Print("Admin creates Flow/FUSD pool")
	// flow transactions send "./transactions/EmuSwap/admin/create_new_pool_FLOW_FUSD.cdc" 100.0 500.0 --signer "admin-account"
	o.TransactionFromFile("EmuSwap/admin/create_new_pool_FLOW_FUSD").
		SignProposeAndPayAs("account").
		Args(o.
			Arguments().
			UFix64(1000.0).
			UFix64(500.0)).
		RunPrintEventsFull()

	o.ScriptFromFile("get_dao_fee_percentage").Run()
	o.ScriptFromFile("get_lp_fee_percentage").Run()

	fmt.Print("Admin updates LP fee percentage")
	o.TransactionFromFile("EmuSwap/admin/update_lp_fee_percentage").
		SignProposeAndPayAs("account").
		Args(o.Arguments().
			UInt64(0).
			UFix64(0.0025)).
		RunPrintEventsFull()

	fmt.Print("Admin updates DAO fee percentage")
	o.TransactionFromFile("EmuSwap/admin/update_dao_fee_percentage").
		SignProposeAndPayAs("account").
		Args(o.Arguments().
			UInt64(0).
			UFix64(0.0025)).
		RunPrintEventsFull()

	o.ScriptFromFile("get_pool_ids").Run()
	o.ScriptFromFile("get_pool_meta").Args(o.Arguments().UInt64(0)).Run()
	o.ScriptFromFile("get_pools_meta").Run()

	// Get quotes
	fmt.Print("Getting quotes:")
	o.ScriptFromFile("pool/get_quotes").Args(o.Arguments().UInt64(0).UFix64(1.0)).Run()
	o.ScriptFromFile("pool/get_quote_a_to_exact_b").Args(o.Arguments().UInt64(0).UFix64(1.0)).Run()
	o.ScriptFromFile("pool/get_quote_b_to_exact_a").Args(o.Arguments().UInt64(0).UFix64(1.0)).Run()
	o.ScriptFromFile("pool/get_quote_exact_a_to_b").Args(o.Arguments().UInt64(0).UFix64(1.0)).Run()
	o.ScriptFromFile("pool/get_quote_exact_b_to_a").Args(o.Arguments().UInt64(0).UFix64(1.0)).Run()

	// Swap
	fmt.Print("User 1 Swaps 1.0 Flow for FUSD")
	o.TransactionFromFile("EmuSwap/user/swap_flow_for_fusd").
		SignProposeAndPayAs("user1").
		Args(o.Arguments().
			UFix64(1.0)).
		RunPrintEventsFull()

	o.ScriptFromFile("get_pools_meta").Run()
	o.ScriptFromFile("pool/get_quotes").Args(o.Arguments().UInt64(0).UFix64(1.0)).Run()

	fmt.Print("User 2 Swaps 1.0 FUSD for Flow")
	o.TransactionFromFile("EmuSwap/user/swap_flow_for_fusd").
		SignProposeAndPayAs("user2").
		Args(o.Arguments().
			UFix64(1.0)).
		RunPrintEventsFull()

	o.ScriptFromFile("get_pools_meta").Run()
	o.ScriptFromFile("pool/get_quotes").Args(o.Arguments().UInt64(0).UFix64(1.0)).Run()

	fmt.Print("User 1 Swaps 1.0 Flow for FUSD")
	o.TransactionFromFile("EmuSwap/user/swap_flow_for_fusd").
		SignProposeAndPayAs("user1").
		Args(o.Arguments().
			UFix64(1.0)).
		RunPrintEventsFull()

	o.ScriptFromFile("get_pools_meta").Run()
	o.ScriptFromFile("pool/get_quotes").Args(o.Arguments().UInt64(0).UFix64(1.0)).Run()

	fmt.Print("User 2 Swaps 1.0 FUSD for Flow")
	o.TransactionFromFile("EmuSwap/user/swap_flow_for_fusd").
		SignProposeAndPayAs("user2").
		Args(o.Arguments().
			UFix64(1.0)).
		RunPrintEventsFull()

	o.ScriptFromFile("get_pools_meta").Run()
	o.ScriptFromFile("pool/get_quotes").Args(o.Arguments().UInt64(0).UFix64(1.0)).Run()

	// Add Liquidity
	fmt.Print("User 1 adds liquidity 200 1000")
	o.TransactionFromFile("EmuSwap/user/add_liquidity").
		SignProposeAndPayAs("user1").
		Args(o.
			Arguments().
			String("flowTokenVault").
			UFix64(200.0).
			String("fusdVault").
			UFix64(1000.0)).
		RunPrintEventsFull()

	fmt.Print("User 2 adds liquidity Flow/FUSD 200 1000")
	o.TransactionFromFile("EmuSwap/user/add_liquidity").
		SignProposeAndPayAs("user2").
		Args(o.Arguments().
			String("flowTokenVault").
			UFix64(200.0).
			String("fusdVault").
			UFix64(1000.0)).
		RunPrintEventsFull()

	poolID := uint64(0)

	fmt.Print("User 1 withdraws liquidity")
	o.TransactionFromFile("EmuSwap/user/remove_liquidity").
		SignProposeAndPayAs("user1").
		Args(o.Arguments().
			UInt64(poolID).
			UFix64(0.001).
			String("flowTokenVault").
			String("fusdVault")).
		RunPrintEventsFull()

	o.ScriptFromFile("pool/get_quotes").Args(o.Arguments().UInt64(0).UFix64(1.0)).Run()
	o.ScriptFromFile("read_fees_collected").Run()

	// Staking
	//

	// flow transactions send "./transactions/Staking/admin/toggle_mock_time.cdc" --signer "admin-account"
	o.TransactionFromFile("Staking/admin/toggle_mock_time").
		SignProposeAndPayAs("account").
		RunPrintEventsFull()

	fmt.Print("Admin creates new farm")
	// flow transactions send "./transactions/Staking/admin/create_new_farm.cdc" 0 --signer "admin-account"
	o.TransactionFromFile("Staking/admin/create_new_farm").
		SignProposeAndPayAs("account").
		Args(o.
			Arguments().
			UInt64(0)).
		RunPrintEventsFull()

	fmt.Print("Admin creates rewards pool FUSD")
	// flow transactions send "./transactions/Staking/admin/create_reward_pool_fusd.cdc" 100000.0 --signer admin-account
	o.TransactionFromFile("Staking/admin/create_reward_pool_fusd").
		SignProposeAndPayAs("account").
		Args(o.
			Arguments().
			UFix64(100000.0)).
		RunPrintEventsFull()

	fmt.Print("Admin creates new farm")
	// flow transactions send "./transactions/Staking/admin/update_mock_timestamp.cdc" 1.0 --signer "admin-account"
	o.TransactionFromFile("Staking/admin/update_mock_timestamp").
		SignProposeAndPayAs("account").
		Args(o.
			Arguments().
			UFix64(1.0)).
		RunPrintEventsFull()

	fmt.Print("User1 Stakes 0.001")
	// flow transactions send "./transactions/Staking/user/stake.cdc" 1.0 --signer "user-account1"
	o.TransactionFromFile("Staking/user/stake").
		SignProposeAndPayAs("user1").
		Args(o.
			Arguments().
			UInt64(0).
			UFix64(0.001)).
		RunPrintEventsFull()

	// flow transactions send "./transactions/Staking/admin/update_mock_timestamp.cdc" 100.0 --signer "admin-account"
	o.TransactionFromFile("Staking/admin/update_mock_timestamp").
		SignProposeAndPayAs("account").
		Args(o.
			Arguments().
			UFix64(100.0)).
		RunPrintEventsFull()

		// flow transactions send "./transactions/Staking/user/claim_rewards.cdc" 0 --signer "user-account1"
	o.TransactionFromFile("Staking/user/claim_rewards").
		SignProposeAndPayAs("user1").
		Args(o.
			Arguments().
			UInt64(0)).
		RunPrintEventsFull()

		// flow transactions send "./transactions/Staking/user/stake.cdc" 1.0 --signer "user-account2"
	o.TransactionFromFile("Staking/user/stake").
		SignProposeAndPayAs("user2").
		Args(o.
			Arguments().
			UInt64(0).
			UFix64(0.18999999)).
		RunPrintEventsFull()

	fmt.Print("User 1 Withdraws half their staked LP Tokens (0.0005) ")
	// flow transactions send "./transactions/Staking/user/unstake.cdc" 0 0.5 --signer "user-account1"
	o.TransactionFromFile("Staking/user/unstake").
		SignProposeAndPayAs("user1").
		Args(o.
			Arguments().
			UInt64(0).
			UFix64(0.0005)).
		RunPrintEventsFull()

	//flow scripts execute "./scripts/Staking/get_farm_meta.cdc" 0
	o.ScriptFromFile("Staking/get_farm_meta").Args(o.Arguments().UInt64(0)).Run()

	//flow scripts execute "./scripts/Staking/get_pending_rewards.cdc" 0 0x179b6b1cb6755e31
	o.ScriptFromFile("Staking/get_pending_rewards").Args(o.Arguments().UInt64(0).Account("user1")).Run()
	o.ScriptFromFile("Staking/get_pending_rewards").Args(o.Arguments().UInt64(0).Account("user2")).Run()
	o.ScriptFromFile("Staking/get_pending_rewards").Args(o.Arguments().UInt64(0).Account("user3")).Run()

	/*
		//# flow transactions send "./transactions/Staking/user/add_liquidity_and_stake.cdc" 10.0 10.0 --signer "user-account1"
		o.TransactionFromFile("Staking/user/add_liquidity_and_stake").
			SignProposeAndPayAs("user1").
			Args(o.
				Arguments().
				UFix64(0.01).
				UFix64(0.01)).
			RunPrintEventsFull()
	*/

	//# flow transactions send "./transactions/Staking/user/unstake.cdc" 0 0.001 --signer "user-account1"
	o.TransactionFromFile("Staking/user/unstake").
		SignProposeAndPayAs("user1").
		Args(o.
			Arguments().
			UInt64(0).
			UFix64(0.0001)).
		RunPrintEventsFull()

	//# flow transactions send "./transactions/Staking/user/unstake.cdc" 0 0.001 --signer "user-account2"
	o.TransactionFromFile("Staking/user/unstake").
		SignProposeAndPayAs("user2").
		Args(o.
			Arguments().
			UInt64(0).
			UFix64(0.00005)).
		RunPrintEventsFull()

	//#flow scripts execute "./scripts/Staking/get_farm_meta.cdc" 0

	o.ScriptFromFile("Staking/get_farm_meta").Args(o.Arguments().UInt64(0)).Run()

	//# flow scripts execute "./scripts/Staking/get_pending_rewards.cdc" 0 0x01cf0e2f2f715450
	// #flow scripts execute "./scripts/Staking/get_pending_rewards.cdc" 0 0x179b6b1cb6755e31
	// #flow scripts execute "./scripts/Staking/get_pending_rewards.cdc" 0 0xf3fcd2c1a78f5eee
	o.ScriptFromFile("Staking/get_pending_rewards").Args(o.Arguments().UInt64(0).Account("account")).Run()
	o.ScriptFromFile("Staking/get_pending_rewards").Args(o.Arguments().UInt64(0).Account("user1")).Run()
	o.ScriptFromFile("Staking/get_pending_rewards").Args(o.Arguments().UInt64(0).Account("user2")).Run()
	o.ScriptFromFile("Staking/get_pending_rewards").Args(o.Arguments().UInt64(0).Account("user3")).Run()

	// echo "update timestamp +100"
	// flow transactions send "./transactions/Staking/admin/update_mock_timestamp.cdc" 100.0 --signer "admin-account"
	o.TransactionFromFile("Staking/admin/update_mock_timestamp").
		SignProposeAndPayAs("account").
		Args(o.
			Arguments().
			UFix64(100.0)).
		RunPrintEventsFull()

	o.ScriptFromFile("Staking/get_pending_rewards").Args(o.Arguments().UInt64(0).Account("account")).Run()
	o.ScriptFromFile("Staking/get_pending_rewards").Args(o.Arguments().UInt64(0).Account("user1")).Run()
	o.ScriptFromFile("Staking/get_pending_rewards").Args(o.Arguments().UInt64(0).Account("user2")).Run()
	o.ScriptFromFile("Staking/get_pending_rewards").Args(o.Arguments().UInt64(0).Account("user3")).Run()

	// #flow transactions send "./transactions/tick.cdc"
	o.TransactionFromFile("tick").
		SignProposeAndPayAs("account").
		RunPrintEventsFull()

		// echo "should be 100 tokens shared between these two"

	// flow scripts execute "./scripts/Staking/get_farm_meta.cdc" 0
	o.ScriptFromFile("Staking/get_farm_meta").Args(o.Arguments().UInt64(0)).Run()

	// flow transactions send "./transactions/Staking/user/claim_rewards.cdc" 0 --signer "user-account1"
	o.TransactionFromFile("Staking/user/claim_rewards").
		SignProposeAndPayAs("user1").
		Args(o.
			Arguments().
			UInt64(0)).
		RunPrintEventsFull()

	// # flow transactions send "./transactions/Staking/user/claim_rewards.cdc" 0 --signer "user-account2"
	o.TransactionFromFile("Staking/user/claim_rewards").
		SignProposeAndPayAs("user2").
		Args(o.
			Arguments().
			UInt64(0)).
		RunPrintEventsFull()

	// flow transactions send "./transactions/Staking/user/claim_rewards.cdc" 0 --signer "user-account1"
	o.TransactionFromFile("Staking/user/claim_rewards").
		SignProposeAndPayAs("user1").
		Args(o.
			Arguments().
			UInt64(0)).
		RunPrintEventsFull()

	// flow transactions send "./transactions/Staking/user/claim_rewards.cdc" 0 --signer "user-account2"
	o.TransactionFromFile("Staking/user/claim_rewards").
		SignProposeAndPayAs("user2").
		Args(o.
			Arguments().
			UInt64(0)).
		RunPrintEventsFull()

	// # flow transactions send "./transactions/Staking/admin/create_reward_pool_fusd.cdc" /storage/fusdVault 0.1 --signer admin-account
	// # flow transactions send "./transactions/Staking/admin/create_reward_pool_fusd.cdc" /storage/flowTokenVault 0.1 --signer admin-account
	// flow transactions send "./transactions/Staking/admin/create_reward_pool_fusd.cdc" 100000.0 --signer admin-account

	// o.TransactionFromFile("FUSD/setup").SignProposeAndPayAs("user1").RunPrintEventsFull()
	// o.TransactionFromFile("FUSD/setup").SignProposeAndPayAs("user2").RunPrintEventsFull()

	// o.TransactionFromFile("demo/mintFlowTokens").SignProposeAndPayAs("account").Args(o.Arguments().UFix64(1000.0).Account("user-account1")).RunPrintEventsFull()
	// o.TransactionFromFile("demo/mintFlowTokens").SignProposeAndPayAs("account").Args(o.Arguments().UFix64(1000.0).Account("user-account2")).RunPrintEventsFull()
	// o.TransactionFromFile("demo/mintFlowTokens").SignProposeAndPayAs("account").Args(o.Arguments().UFix64(1000.0).Account("user-account3")).RunPrintEventsFull()

	// o.TransactionFromFile("FUSD/setup").SignProposeAndPayAs("account").RunPrintEventsFull()
	// o.TransactionFromFile("FUSD/setup").SignProposeAndPayAs("user-account1").RunPrintEventsFull()
	// o.TransactionFromFile("FUSD/setup").SignProposeAndPayAs("user-account2").RunPrintEventsFull()
	// o.TransactionFromFile("FUSD/setup").SignProposeAndPayAs("user-account3").RunPrintEventsFull()
	// o.TransactionFromFile("EmuSwap/admin/create_new_pool_FLOW_FUSD").SignProposeAndPayAs("account").Args(o.Arguments().UFix64(100.0).UFix64(500.0)).RunPrintEventsFull()

	// 	//NameArguments supports
	// 	o.TransactionFromFile("arguments").SignProposeAndPayAs("first").NamedArguments(map[string]string{
	// 		"test": "argument1",
	// 	}).RunPrintEventsFull()

	// 	structValue := cadence.Struct{
	// 		Fields: []cadence.Value{cadence.String("baz")},
	// 		StructType: &cadence.StructType{
	// 			QualifiedIdentifier: "A.f8d6e0586b0a20c7.Debug.Foo",
	// 			Fields: []cadence.Field{{
	// 				Identifier: "bar",
	// 				Type:       cadence.StringType{},
	// 			}},
	// 		},
	// 	}

	// 	o.Transaction(`
	// import Debug from "../contracts/Debug.cdc"
	// transaction(value:Debug.Foo) {
	// 	prepare(acct: AuthAccount) {
	// 	Debug.log(value.bar)
	//  }
	// }`).SignProposeAndPayAs("first").Args(o.Arguments().Argument(structValue)).RunPrintEventsFull()

	//this first transaction will setup a NFTCollection for the user "emulator-first".
	// transactions are looked up in the `transactions` folder.
	//if we change the initialization of overflow to testnet above the account used here would be "testnet-first".
	// finally we run the transaction and print all the events, there are several convenience methods to filter out fields from events of not print them at all if you like.
	// o.TransactionFromFile("create_nft_collection").SignProposeAndPayAs("first").RunPrintEventsFull()

	// 	//the second transaction show how you can call a transaction with an argument. In this case we send a string to the transactions
	// 	o.TransactionFromFile("arguments").SignProposeAndPayAs("first").Args(o.Arguments().String("argument1")).RunPrintEventsFull()

	// 	//it is possible to send an accounts address as argument to a script using a convenience function `Account`. Network is prefixed here as well
	// 	o.TransactionFromFile("argumentsWithAccount").SignProposeAndPayAs("first").Args(o.Arguments().Account("second")).RunPrintEventsFull()

	// 	//This transactions shows an example of signing the main envelope with the "first" user and the paylod with the "second" user.
	// 	o.TransactionFromFile("signWithMultipleAccounts").SignProposeAndPayAs("first").PayloadSigner("second").Args(o.Arguments().String("asserts.go")).RunPrintEventsFull()

	// 	//Running a script from a file is almost like running a transaction.
	// 	o.ScriptFromFile("test").Args(o.Arguments().Account("second")).Run()

	// 	//In this transaction we actually do some meaningful work. We mint 10 flowTokens into the account of user first. Note that this method will not work on mainnet or testnet. If you want tokens on testnet use the faucet or transfer from one account to another
	// 	o.TransactionFromFile("mint_tokens").SignProposeAndPayAsService().Args(o.Arguments().Account("first").UFix64(10.0)).RunPrintEventsFull()

	// 	//If you do not want to store a script in a file you can use a inline representation with go multiline strings
	// 	o.Script(`
	// pub fun main(account: Address): String {
	// 		return getAccount(account).address.toString()
	// }`).Args(o.Arguments().Account("second")).Run()

	// 	//The same is also possible for a transaction. Also note the handy Debug contracts log method that allow you to assert some output from a transaction other then an event.
	// 	o.Transaction(`
	// import Debug from "../contracts/Debug.cdc"
	// transaction(value:String) {
	// 	prepare(acct: AuthAccount) {
	// 	Debug.log(value)
	//  }
	// }`).SignProposeAndPayAs("first").Args(o.Arguments().String("foobar")).RunPrintEventsFull()

	// 	//Run script that returns
	// 	result := o.ScriptFromFile("test").Args(o.Arguments().Account("second")).RunFailOnError()
	// 	fmt.Printf("Script returned %s", result)

}
