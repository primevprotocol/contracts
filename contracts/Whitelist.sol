// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.15;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Contract that allows an admin to add/remove addresses from the whitelist,
// and allows whitelisted addresses to mint/burn native tokens.
contract Whitelist is Ownable {

    mapping(address => bool) public whitelistedAddresses;

    // Mint/burn precompile addresses.
    // See: https://github.com/primevprotocol/go-ethereum/blob/03ae168c6ac15dda8c5a3f123e2b9f3350aad613/core/vm/contracts.go
    address constant MINT = address(0x89);
    address constant BURN = address(0x90);

    constructor(address _owner) Ownable() {
        _transferOwnership(_owner);
    }

    function addToWhitelist(address _address) external onlyOwner {
        whitelistedAddresses[_address] = true;
    }

    function removeFromWhitelist(address _address) external onlyOwner {
        whitelistedAddresses[_address] = false;
    }

    function isWhitelisted(address _address) public view returns (bool) {
        return whitelistedAddresses[_address];
    }

    // Mints native tokens if the sender is whitelisted.
    // See: https://github.com/primevprotocol/go-ethereum/blob/precompile-updates/core/vm/contracts_with_ctx.go#L83
    function mint(address _mintTo, uint256 _amount) external {
        require(isWhitelisted(msg.sender), "Sender is not whitelisted");
        bool success;
        (success, ) = MINT.call{value: 0, gas: gasleft()}(
            abi.encode(_mintTo, _amount)
        );
        require(success, "Native mint failed");
    }

    // Burns native tokens if the sender is whitelisted.
    function burn(address _burnFrom, uint256 _amount) external {
        require(isWhitelisted(msg.sender), "Sender is not whitelisted");
        
        // require _burnFrom has enough balance. This check is NOT done at the precompile level.
        // Reason: https://github.com/primevprotocol/go-ethereum/blob/8735a9bbe6965ed68371472cb0794d8659a94428/core/vm/contracts_with_ctx.go#L115
        require(_burnFrom.balance >= _amount, "Insufficient balance");

        bool success;
        (success, ) = BURN.call{value: 0, gas: gasleft()}(
            abi.encode(_burnFrom, _amount) 
        );
        require(success, "Native burn failed");
    }
}
