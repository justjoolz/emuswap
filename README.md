# Emuswap

EmuSwap - Multi token swap contract.

- Admin can 
    - create new pool by providing inital liquidity
    - freeze/unfreeze any pool (new pools frozen by default) 

- Users can interact with any pool
    - Trade
    - Add liquidity
    - Remove liquidity

## Emulator Tests

1. Run emulator ``` flow emulator --verbose```

2. In new terminal window ```./bash/test.sh```

## Notes on test accounts 

The test account key details in flow.json were created as follows:

First generate a determenistic key pairs from seed (minimum 32byte seed)

```
flow keys generate --seed="abcdefghijklmnopqrstuvwxyz0123456789"
```

Returns:
- Private Key:  	                
bda17f3a07e924c56f66e76a38246259f17b66c5f6233fd1db4c32ba8b1702b6
- Public Key 	 2921bbc5acf75417b09ef1cc7981f2a57cc7ee00df71afaddde94991b6f26fb4da66a4b9bea1ee8a555dbba62626ba7c0437e4c6800d25203c915161bed6e4f2

```
flow keys generate --seed="Test_User_Account_seed_phrase_000001"
```

Returns:
- Private Key: 	 
    c3c402f4b5ac76dd16b9d60de899c01e2d3c5ae153efdd2ca7fe91ad754abd73
- Public Key:	        e5b78d3e1d28ecccaa62bbf869df5b6b06a3f0330a46651b2e29c5a0e53b4cd9659f2a0a0555c6de55caedc08475a81e6670ec62c93acbcfe62a45a20226a323

```
flow keys generate 
--seed="Test_User_Account_seed_phrase_000002"
```

- Private Key: c89af7e50eb5c927e66d040a93e02a7a6ffbcd950ab9d6fcbea235f9217b4836
- Public Key:	 62410c9c523d7a04f8b5c1b478cbada16d70125be9c8e137baa843a16a430da70d215fb6d6fc9ca68d4b7b3f2e7624db8785006b3fe977e25ca459612178723a


## Feed public key(s) to create account(s)

```
flow accounts create --key="2921bbc5acf75417b09ef1cc7981f2a57cc7ee00df71afaddde94991b6f26fb4da66a4b9bea1ee8a555dbba62626ba7c0437e4c6800d25203c915161bed6e4f2"
```

Returns: 0x01cf0e2f2f715450

```
flow accounts create --key="e5b78d3e1d28ecccaa62bbf869df5b6b06a3f0330a46651b2e29c5a0e53b4cd9659f2a0a0555c6de55caedc08475a81e6670ec62c93acbcfe62a45a20226a323"
```

Returns: 0x179b6b1cb6755e31

```
flow accounts create --key="62410c9c523d7a04f8b5c1b478cbada16d70125be9c8e137baa843a16a430da70d215fb6d6fc9ca68d4b7b3f2e7624db8785006b3fe977e25ca459612178723a"
```

Returns: 0xf3fcd2c1a78f5eee


These accounts are hardcoded and aliased in flow.json 

Accounts need to be created manually 'onchain' after launching the emulator.

The setup.sh script automates the account creation.

