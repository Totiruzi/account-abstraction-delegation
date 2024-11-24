// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccount} from "@foundry/src/system-contracts/contracts/interfaces/IAccount.sol";
import {Transaction} from "@foundry/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";

/**
 * @title Account Abstraction Transaction (type 113)
 * @author Chris Onowu
 * @notice Creating a Minimal Account
 * 
 * Lifecycle of a type 113 (0x17) transaction
 * msg.sender is the bootloader system contract
 * 
 * Phase 1 Validation
 * 1. The user sends the transaction to the user API client (a sort of a "light node")
 * 2. The ZkSync API client check to see if the nonce is unique by queering the NonceHolder system contract
 * 3. The ZkSync API client calls validateTransaction which MUST updates the nonce
 * 4. The ZkSync API client checks the nonce is updated
 * 5. The ZkSync API client calls payForTransaction, or prepareForPaymaster & validateAndPayForPaymasterTransaction
 * 6. The ZkSync API verifiers that the bootloader gets paid
 * 
 * Phase 2 Execution
 * 7. The ZkSync API client pass the validated transaction to the main node / sequencer (as of today they are the same)
 * 8. The main node calls execute transaction
 * 9. If a paymaster is used, the postTransaction is called
 */


contract ZkMinimalAccount is IAccount {
    function validateTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction memory _transaction)
        external
        payable
        returns (bytes4 magic)
    {}

    function executeTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction memory _transaction)
        external
        payable
    {}

    // There is no point in providing possible signed hash in the `executeTransactionFromOutside` method,
    // since it typically should not be trusted.
    function executeTransactionFromOutside(Transaction memory _transaction) external payable {}

    function payForTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction memory _transaction)
        external
        payable
    {}

    function prepareForPaymaster(bytes32 _txHash, bytes32 _possibleSignedHash, Transaction memory _transaction)
        external
        payable
    {}
}
