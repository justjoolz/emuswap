j00lz's double DOXED link ->
https://docs.google.com/document/d/1Np-Yd6ktWM3pEUJy-YqcvbiL2QFX-abIeiQt3dV6y14/edit

Start
    500
Fork Bloctoswap (total ~5weeks)
    Refactor Contract to allow adding/removing LP token pairs (2-3 weeks)       nearly done?
    Write update scripts and transactions to new architecture (1week)           started :) 
    Write unit tests + user story tests (1week)                                 kinda started
    3250

Plan staking architecture + tokenomics + NFT gamification (1-2week) 
    3250

Create Platform FungibleToken contract (1-2 weeks)
    3250

Create Staking Contract (3-4 weeks)
    3250

Create multi user staking story tests (2-3 weeks) - (including mocking time)
    3250

Refactoring/optimization via contract review (1-2 weeks)
    3250

Total ~12-18 weeks 



end of week1
Friday Jan 28th.... where am I at? 

    - Updated Bloctoswap contract to use generic FungibleToken rather than importing specific implementation contract
    - Admin functions not updated....

    Experimented with 2 approaches to managing LPVaults 
        1) FungibleTokens - Fungible Token contract but with added ID field to each Vault.....
                            - Main problem is storing the Vaults in correct location by ID (Cadence doesn't support programatically creating paths quite yet but it's documented already so must be coming soon!)

        2) FungibleTokens   - Created from FungibleToken interface contract but with added ID and a Collection as per NFT standard.... haven't tried implementing this in the EmuSwap contract yet. 
        

Friday 11th Feb

    - Finished majority of first milestone


j00lz 2do add events to EmuSwap 

    



Staking Architechture

    1. xEMU = Auto Compounding Staked EMU 
        - xEmu FungibleToken Contract...
            - Transaction is run to:
                - Withdraw fees collected from EmuSwap
                - Swap all fees for Emu
                - Deposit ('Donate') Emu to EMU/xEMU LP pool
            - Exchange Emu <-> xEmu
            - 



function enter(uint256 _amount) public {
        // Gets the amount of Joe locked in the contract
        uint256 totalJoe = joe.balanceOf(address(this));
        // Gets the amount of xJoe in existence
        uint256 totalShares = totalSupply();
        // If no xJoe exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || totalJoe == 0) {
            _mint(msg.sender, _amount);
        }
        // Calculate and mint the amount of xJoe the Joe is worth. The ratio will change overtime, as xJoe is burned/minted and Joe deposited + gained from fees / withdrawn.
        else {
            uint256 what = _amount.mul(totalShares).div(totalJoe);
            _mint(msg.sender, what);
        }
        // Lock the Joe in the contract
        joe.transferFrom(msg.sender, address(this), _amount);
    }

    // Leave the bar. Claim back your JOEs.
    // Unlocks the staked + gained Joe and burns xJoe
    function leave(uint256 _share) public {
        // Gets the amount of xJoe in existence
        uint256 totalShares = totalSupply();
        // Calculates the amount of Joe the xJoe is worth
        uint256 what = _share.mul(joe.balanceOf(address(this))).div(totalShares);
        _burn(msg.sender, _share);
        joe.transfer(msg.sender, what);
    }

    







Multisign DAO Inbox

    - Contract that allows users to register and receive an inboxResource.
    - DAO can send capability to another user to send transactions to be signed
    - User with with capability can send transaction to be co-signed 
        - Graffle hook for inbox insert event 
    - User receives push inbox notification from backend
    - User logs in a signs transaction and sends to network
        - direct to network or via centralized backend for final signature of payer?
    - Bingo Multisignature DAO transaction approval
