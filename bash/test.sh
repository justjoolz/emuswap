# Bash script for testing contracts, transactions and scripts against the emulator. 
# 1. Create accounts 

# Create 3 accounts for testing purposes. 
# See README for additional details

echo "Creating Admin account: "
flow accounts create --key="2921bbc5acf75417b09ef1cc7981f2a57cc7ee00df71afaddde94991b6f26fb4da66a4b9bea1ee8a555dbba62626ba7c0437e4c6800d25203c915161bed6e4f2"

echo "Creating User1 account 0x179b6b1cb6755e31"
flow accounts create --key="e5b78d3e1d28ecccaa62bbf869df5b6b06a3f0330a46651b2e29c5a0e53b4cd9659f2a0a0555c6de55caedc08475a81e6670ec62c93acbcfe62a45a20226a323"

echo "Creating User2 account 0xf3fcd2c1a78f5eee"
flow accounts create --key="62410c9c523d7a04f8b5c1b478cbada16d70125be9c8e137baa843a16a430da70d215fb6d6fc9ca68d4b7b3f2e7624db8785006b3fe977e25ca459612178723a"

# 2. Mint Flow tokens

# Flow tokens required for admin-account to be able to deploy contracts without running out of storage space.
# mintFlowTokens amount recipientAddress
flow transactions send "./transactions/demo/mintFlowTokens.cdc" 1000.0 0x01cf0e2f2f715450
flow transactions send "./transactions/demo/mintFlowTokens.cdc" 1000.0 0x179b6b1cb6755e31
flow transactions send "./transactions/demo/mintFlowTokens.cdc" 1000.0 0xf3fcd2c1a78f5eee


flow project deploy --network emulator


# 3. Setup accounts FUSD.

flow transactions send "./transactions/FUSD/setup.cdc" --signer "admin-account"
flow transactions send "./transactions/FUSD/setup.cdc" --signer "user-account1"
flow transactions send "./transactions/FUSD/setup.cdc" --signer "user-account2"

# Setup EmuToken 
flow transactions send "./transactions/EmuToken/setup.cdc" --signer "admin-account"
flow transactions send "./transactions/EmuToken/setup.cdc" --signer "user-account1"
flow transactions send "./transactions/EmuToken/setup.cdc" --signer "user-account2"


flow transactions send "./transactions/demo/mintFUSD.cdc" 1000000.0 0x01cf0e2f2f715450
flow transactions send "./transactions/demo/mintFUSD.cdc" 1000000.0 0x179b6b1cb6755e31
flow transactions send "./transactions/demo/mintFUSD.cdc" 1000000.0 0xf3fcd2c1a78f5eee

# 4. Create Pools (admin adds 10 Flow + 50 FUSD)
flow transactions send "./transactions/EmuSwap/admin/create_new_pool_FLOW_FUSD.cdc" 100.0 500.0 --signer "admin-account"

# User 1 Adds liquidity
flow transactions send "./transactions/EmuSwap/exchange/add_liquidity_FLOW_FUSD.cdc" 200.0 1000.0 --signer "user-account1"

# User 2 Adds liquidity
flow transactions send "./transactions/EmuSwap/exchange/add_liquidity_FLOW_FUSD.cdc" 200.0 1000.0 --signer "user-account2"

# Create new farm for pool 0 = Flow/FUSD
flow transactions send "./transactions/Staking/admin/toggle_mock_time.cdc" --signer "admin-account"
flow transactions send "./transactions/Staking/admin/create_new_farm.cdc" 0 --signer "admin-account"



echo "Create FUSD reward Pool" 
flow transactions send "./transactions/Staking/admin/create_reward_pool_fusd.cdc" 100000.0 --signer admin-account




flow transactions send "./transactions/Staking/admin/update_mock_timestamp.cdc" 1.0 --signer "admin-account"


echo "USER 1 Stakes 1 "

flow transactions send "./transactions/Staking/user/stake.cdc" 1.0 --signer "user-account1"
# 60*60*24*27 = 2,332,800

echo "Update Timestamp +100"
flow transactions send "./transactions/Staking/admin/update_mock_timestamp.cdc" 100.0 --signer "admin-account"

echo "user 1 claims rewards"
flow transactions send "./transactions/Staking/user/claim_rewards.cdc" 0 --signer "user-account1"
echo "should have claimed 100 tokens"

echo "user 2 stakes"
flow transactions send "./transactions/Staking/user/stake.cdc" 1.0 --signer "user-account2"

#echo "user 1 unstakes half"
#flow transactions send "./transactions/Staking/user/unstake.cdc" 0 0.5 --signer "user-account1"



flow scripts execute "./scripts/Staking/get_farm_meta.cdc" 0
flow scripts execute "./scripts/Staking/get_pending_rewards.cdc" 0 0x179b6b1cb6755e31


# flow transactions send "./transactions/Staking/user/add_liquidity_and_stake.cdc" 10.0 10.0 --signer "user-account1"

# flow transactions send "./transactions/Staking/user/unstake.cdc" 0 0.001 --signer "user-account1"
# flow transactions send "./transactions/Staking/user/unstake.cdc" 0 0.001 --signer "user-account2"

#flow scripts execute "./scripts/Staking/get_farm_meta.cdc" 0
# flow scripts execute "./scripts/Staking/get_pending_rewards.cdc" 0 0x01cf0e2f2f715450
#flow scripts execute "./scripts/Staking/get_pending_rewards.cdc" 0 0x179b6b1cb6755e31
#flow scripts execute "./scripts/Staking/get_pending_rewards.cdc" 0 0xf3fcd2c1a78f5eee


echo "update timestamp +100"
flow transactions send "./transactions/Staking/admin/update_mock_timestamp.cdc" 100.0 --signer "admin-account"
flow scripts execute "./scripts/Staking/get_pending_rewards.cdc" 0 0x179b6b1cb6755e31
flow scripts execute "./scripts/Staking/get_pending_rewards.cdc" 0 0xf3fcd2c1a78f5eee
#flow transactions send "./transactions/tick.cdc"
echo "should be 100 tokens shared between these two"


flow scripts execute "./scripts/Staking/get_farm_meta.cdc" 0
flow scripts execute "./scripts/Staking/read_stakes_info.cdc" 0 


# flow transactions send "./transactions/Staking/user/claim_rewards.cdc" 0 --signer "user-account1"
# flow transactions send "./transactions/Staking/user/claim_rewards.cdc" 0 --signer "user-account2"

flow transactions send "./transactions/Staking/user/claim_rewards.cdc" 0 --signer "user-account1"
flow transactions send "./transactions/Staking/user/claim_rewards.cdc" 0 --signer "user-account2"
flow scripts execute "./scripts/Staking/read_stakes_info.cdc" 0 


flow transactions send "./transactions/Staking/user/stake.cdc" 1.0 --signer "user-account1"

echo "update timestamp +100"
flow transactions send "./transactions/Staking/admin/update_mock_timestamp.cdc" 100.0 --signer "admin-account"

flow scripts execute "./scripts/Staking/get_farm_meta.cdc" 0
flow scripts execute "./scripts/Staking/read_stakes_info.cdc" 0 


# TokenPaths tricky to pass at the moment :/ can't create for some reason..... 

# flow transactions send "./transactions/Staking/admin/create_reward_pool_fusd.cdc" /storage/fusdVault 0.1 --signer admin-account
# flow transactions send "./transactions/Staking/admin/create_reward_pool_fusd.cdc" /storage/flowTokenVault 0.1 --signer admin-account
flow transactions send "./transactions/Staking/admin/create_reward_pool_fusd.cdc" 100000.0 --signer admin-account




# What IS working....
# Staking at different times and checking rewards....

# What IS NOT working.....
# Adding to a stake             FIXED!
# Withdrawing from stake        
# Withdrawing rewards