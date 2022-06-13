package main

import (
	"fmt"

	"github.com/bjartek/overflow/overflow"
)

func main() {
	o := overflow.NewOverflow().Start()
	fmt.Printf("%v", o.State.Accounts())

	// flow transactions send "./transactions/EmuSwap/admin/create_new_pool_FLOW_FUSD.cdc" 100.0 500.0 --signer "admin-account"
	//o.TransactionFromFile("EmuSwap/admin/create_new_pool_FLOW_FUSD").SignProposeAndPayAs("account").NamedArguments(map[string]string{"token1": "100.0", "token2": "500.0"}).RunPrintEventsFull()

	fmt.Print("Minting Flow TOkens")

	o.TransactionFromFile("demo/mintFlowTokens").
		SignProposeAndPayAs("account").
		Args(o.Arguments().
			UFix64(1000.0).
			Account("account")).
		RunPrintEventsFull()

	o.TransactionFromFile("demo/mintFlowTokens").
		SignProposeAndPayAs("account").
		Args(o.Arguments().
			UFix64(1000.0).
			Account("user1")).
		RunPrintEventsFull()

	o.TransactionFromFile("demo/mintFlowTokens").
		SignProposeAndPayAs("account").
		Args(o.Arguments().
			UFix64(1000.0).
			Account("user2")).
		RunPrintEventsFull()

	// Setup FUSD Vaults
	fmt.Print("Setting Up FUSD Vaults")
	o.TransactionFromFile("FUSD/setup").SignProposeAndPayAs("account").RunPrintEventsFull()
	o.TransactionFromFile("FUSD/setup").SignProposeAndPayAs("user1").RunPrintEventsFull()
	o.TransactionFromFile("FUSD/setup").SignProposeAndPayAs("user2").RunPrintEventsFull()
	o.TransactionFromFile("FUSD/setup").SignProposeAndPayAs("user3").RunPrintEventsFull()

	// Mint FUSD
	fmt.Print("Minting FUSD")
	o.TransactionFromFile("demo/mintFUSD").SignProposeAndPayAs("account").Args(o.Arguments().UFix64(200000.0).Address("account")).RunPrintEventsFull()
	o.TransactionFromFile("demo/mintFUSD").SignProposeAndPayAs("account").Args(o.Arguments().UFix64(1000.0).Address("user1")).RunPrintEventsFull()
	o.TransactionFromFile("demo/mintFUSD").SignProposeAndPayAs("account").Args(o.Arguments().UFix64(1000.0).Address("user2")).RunPrintEventsFull()
	o.TransactionFromFile("demo/mintFUSD").SignProposeAndPayAs("account").Args(o.Arguments().UFix64(1000.0).Address("user3")).RunPrintEventsFull()

	fmt.Print("Admin creates Flow/FUSD pool")
	// flow transactions send "./transactions/EmuSwap/admin/create_new_pool_FLOW_FUSD.cdc" 100.0 500.0 --signer "admin-account"
	o.TransactionFromFile("EmuSwap/admin/create_new_pool_FLOW_FUSD").
		SignProposeAndPayAs("account").
		Args(o.
			Arguments().
			UFix64(1000.0).
			UFix64(500.0)).
		RunPrintEventsFull()

	fmt.Print("User 1 adds liquidity 200 1000")
	o.TransactionFromFile("EmuSwap/exchange/add_liquidity_FLOW_FUSD").
		SignProposeAndPayAs("user1").
		Args(o.
			Arguments().
			UFix64(200.0).
			UFix64(1000.0)).
		RunPrintEventsFull()

	fmt.Print("User 2 adds liquidity Flow/FUSD 200 1000")
	o.TransactionFromFile("EmuSwap/exchange/add_liquidity_FLOW_FUSD").
		SignProposeAndPayAs("user2").
		Args(o.
			Arguments().
			UFix64(200.0).
			UFix64(1000.0)).
		RunPrintEventsFull()

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

	fmt.Print("User1 Stakes 1.0")
	// flow transactions send "./transactions/Staking/user/stake.cdc" 1.0 --signer "user-account1"
	o.TransactionFromFile("Staking/user/stake").
		SignProposeAndPayAs("user1").
		Args(o.
			Arguments().
			UFix64(0.2)).
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
			UFix64(0.18999999)).
		RunPrintEventsFull()

	fmt.Print("User 1 Withdraws half their staked LP Tokens (0.1) ")
	// flow transactions send "./transactions/Staking/user/unstake.cdc" 0 0.5 --signer "user-account1"
	o.TransactionFromFile("Staking/user/unstake").
		SignProposeAndPayAs("user1").
		Args(o.
			Arguments().
			UInt64(0).
			UFix64(0.1)).
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
			UFix64(0.001)).
		RunPrintEventsFull()

	//# flow transactions send "./transactions/Staking/user/unstake.cdc" 0 0.001 --signer "user-account2"
	o.TransactionFromFile("Staking/user/unstake").
		SignProposeAndPayAs("user2").
		Args(o.
			Arguments().
			UInt64(0).
			UFix64(0.001)).
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
