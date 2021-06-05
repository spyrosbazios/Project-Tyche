//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

contract PasswordGame {
    
    bool active;

    address[] owners; // owners of the contract
    uint8 interest = 10; // maximum must be 100, eg interest = 10 means 10%

    uint[] betAmounts;
    uint[] winAmounts;
    uint8[] chances;

    struct Bet {
        bool init;
        uint blockNumber;
        uint8 betIndex;
        uint8[9] codes;
    }
    
    mapping (address => Bet) bets;
    
    constructor() {
        active = true;
        owners.push(msg.sender);
        betAmounts = [1 * 1 ether, 2 * 1 ether, 3 * 1 ether];     // randomly chosen, must fix
        winAmounts = [10 * 1 ether, 20 * 1 ether, 30 * 1 ether];  // randomly chosen, must fix
        chances = [2, 4, 8];        // randomly chosen, must fix, should be prime numbers
    }                               // chance is inversed percentage eg chance = 2 means 50%
    
    function getContractBalance() public view returns (uint256) {return address(this).balance;}
    function getChainBlockNumber() public view returns (uint256) {return block.number;}
    
    /* checks if a given address is an owner */
    function isOwner(address addr) public view returns (bool) {
        require(active, "Smart Contract must be active!");
        for (uint i = 0; i < owners.length; i++) {
            if (addr == owners[i]) return true;
        }
        return false;
    }
    
    /* allows an owner to replace his address with another owner */
    function replaceOwner(address newOwner) public {
        require(active, "Smart Contract must be active!");
        //require(isOwner(msg.sender), "You must be already an owner to add new owners!"); omitted to save gas from double loops
        for (uint8 i = 0; i < owners.length; i < i++) {
            if (owners[i] == msg.sender) owners[i] = newOwner;
        }
    }

    /* splits an amount of funds from the contract's address among contract owners */
    function splitFunds(uint amount) public {
        require(active, "Smart Contract must be active!");
        require(isOwner(msg.sender));
        for (uint i = 0; i < owners.length; i++) {
            (bool success,) = owners[i].call{value: amount/owners.length}('');
            assert(success); // if (!success) revert(); works too
        }
    }
    
    /* getters */
    function getBetInit(address addr) public view returns (bool) {return bets[addr].init;}
    function getBetIndex(address addr) public view returns (uint8) {return bets[addr].betIndex;}
    function getBetBlockNumber(address addr) public view returns (uint) {return bets[addr].blockNumber;}
    function getBetCodes(address addr) public view returns (uint8[9] memory) {
        uint8[9] memory c = bets[addr].codes;
        return c;
    }
    /* getters */

    /* creates a bet for a player */
    function createBet(uint8 betIndex, uint8[9] calldata codes) public payable {
        require(active, "Smart Contract must be active!");
        require(msg.value >= betAmounts[betIndex] && !bets[msg.sender].init, "Please make sure you have sufficient funds and no active bets!");
        // require(address(this).balance >= winAmounts[betIndex], "There's not enough money in the contract in case you win!");
        for (uint8 i = 0; i < 9; i++) require(codes[i] >= 1 && codes[i] <= 9);
        require(betIndex < 3);

        bets[msg.sender] = Bet(true, block.number, betIndex, codes);
        uint change = msg.value - betAmounts[betIndex];
        (bool success,) = msg.sender.call{value: change}(''); assert(success);
    }

    /* withdraws a player's bet */
    function withdrawBet() public {
        require(active, "Smart Contract must be active!");
        Bet storage b = bets[msg.sender];
        require(b.init, "You must have placed a bet to withdraw it!");

        uint betAmount = betAmounts[b.betIndex];
        uint betBlockNumber = b.blockNumber;
        delete bets[msg.sender];

        if (block.number == betBlockNumber) {
            (bool success,) = msg.sender.call{value: betAmount}(''); 
            assert(success);
        }
    }

    /* checks if a bet has won */
    function verifyBet() public returns (bool) {
        require(active, "Smart Contract must be active!");
        Bet storage b = bets[msg.sender];
        require(b.init, "You must have placed a bet to verify it!");
        require(block.number > b.blockNumber); // or blockhash will fail because the block won't be mined yet

        uint blockNumber = b.blockNumber;
        uint8[9] memory codes = b.codes;
        uint8 betIndex = b.betIndex;
        delete bets[msg.sender]; // maybe codes are not deleted correctly

        bool verified = verifyCodes(blockNumber, codes, chances[betIndex]);
        if (verified) {
            uint ownerWins = winAmounts[betIndex] * interest / 100;
            uint playerWins = winAmounts[betIndex] - ownerWins;

            for (uint i = 0; i < owners.length; i++) {
                (bool successo,) = owners[i].call{value: ownerWins/owners.length}(''); 
                assert(successo);
            }
            (bool successp,) = msg.sender.call{value: playerWins}(''); assert(successp);
        } else {
            /* ... you have lost ... */
        }      
        return verified;
    }
    
    /* checks if any of a bet's codes has won */
    function verifyCodes(uint blockNumber, uint8[9] memory codes, uint8 chance) private view returns (bool) {
        require(active, "Smart Contract must be active!");
        for (uint i = 0; i < 9; i += 3) {
            uint code = codes[i] * 100 + codes[i+1] * 10 + codes[i+2];
            uint hashedCode = uint(keccak256(abi.encodePacked(bytes32(code), blockhash(blockNumber))));
            if (hashedCode % chance == 0) return true;
        }
        return false;
    }
    
    function deactivate() public {
        require(isOwner(msg.sender), "Only an owner can deactivate the contract");
        splitFunds(address(this).balance);
        active = false;
    }

}

/* 
to-do:
add 2/3 of owners' consensus to deactivate the contract
add events for js
*/
