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

# 4. Deploy Project

flow project deploy 


# 3. Setup accounts FUSD.

flow transactions send "./transactions/FUSD/setup.cdc" --signer "admin-account"
flow transactions send "./transactions/FUSD/setup.cdc" --signer "user-account1"
flow transactions send "./transactions/FUSD/setup.cdc" --signer "user-account2"


flow transactions send "./transactions/demo/mintFUSD.cdc" 1000.0 0x01cf0e2f2f715450
flow transactions send "./transactions/demo/mintFUSD.cdc" 1000.0 0x179b6b1cb6755e31
flow transactions send "./transactions/demo/mintFUSD.cdc" 1000.0 0xf3fcd2c1a78f5eee




# 4. Create Pools

flow transactions send "./transactions/EmuSwap/admin/create_new_pool_FLOW_FUSD.cdc" 10.0 50.0 --signer "admin-account"

flow scripts execute "./scripts/get_pool_ids.cdc"

flow transactions send "./transactions/EmuSwap/exchange/swap_fusd_for_flow.cdc" 1.0 --signer "user-account2"
flow transactions send "./transactions/EmuSwap/exchange/swap_flow_for_fusd.cdc" 1.0 --signer "user-account1"