// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * ZkSync Era imports
 */
import {IAccount, ACCOUNT_VALIDATION_SUCCESS_MAGIC} from "@foundry/contracts/interfaces/IAccount.sol";
import {Transaction, MemoryTransactionHelper} from "@foundry/contracts/libraries/MemoryTransactionHelper.sol";
import {SystemContractsCaller} from "@foundry/contracts/libraries/SystemContractsCaller.sol";
import {
    NONCE_HOLDER_SYSTEM_CONTRACT,
    BOOTLOADER_FORMAL_ADDRESS,
    DEPLOYER_SYSTEM_CONTRACT
} from "@foundry/contracts/Constants.sol";
import {INonceHolder} from "@foundry/contracts/interfaces/INonceHolder.sol";
import {Utils} from "@foundry/contracts/libraries/Utils.sol";

/**
 * Openzeppelin imports
 */
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

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
contract ZkMinimalAccount is IAccount, Ownable {
    using MemoryTransactionHelper for Transaction;

    /**
     * ERRORS
     */
    error ZkMinimalAccount__NotEnoughBalance();
    error ZkMinimalAccount__NotFromBootLoader();
    error ZkMinimalAccount__NotFromBootLoaderOrOwner();
    error ZkMinimalAccount__ExecutionFailed();

    /**
     * MODIFIERS
     */
    modifier requireFromBootLoader() {
        require(msg.sender == BOOTLOADER_FORMAL_ADDRESS, ZkMinimalAccount__NotFromBootLoader());
        _;
    }

    modifier requireFromBootLoaderOrOwner() {
        require(
            msg.sender == BOOTLOADER_FORMAL_ADDRESS && msg.sender == owner(),
            ZkMinimalAccount__NotFromBootLoaderOrOwner()
        );
        _;
    }

    /**
     * FUNCTIONS
     */
    constructor() Ownable(msg.sender) {}

    /**
     * EXTERNAL FUNCTIONS
     */

    /**
     * @notice Called by the bootloader to validate that an account agrees to process the transaction (and potentially pay for it).
     * @param _txHash The hash of the transaction to be used in the explorer
     * @param _suggestedSignedHash The hash of the transaction is signed by EOAs
     * @param _transaction The transaction itself
     * @return magic The magic value that should be equal to the signature of this function if the user agrees to proceed with the transaction.
     * @dev The developer should strive to preserve as many steps as possible both for valid and invalid transactions as this very method is also used during the gas fee estimation (without some of the necessary data, e.g. signature).
     * @notice must increase nonce
     * @notice must validate the transaction (Check the owner signed the transaction)
     * @notice also check tom see if we have enough money in our account
     */
    function validateTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction memory _transaction)
        external
        payable
        requireFromBootLoader
        returns (bytes4 magic)
    {
        /**
         * 1. call nonceHolder
         * 2. increment the nonce
         */
        SystemContractsCaller.systemCallWithPropagatedRevert(
            uint32(gasleft()),
            address(NONCE_HOLDER_SYSTEM_CONTRACT),
            0,
            abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, (_transaction.nonce))
        );

        // Check for fee to pay
        uint256 totalRequiredBalance = _transaction.totalRequiredBalance();
        // if (totalRequiredBalance > address(this).balance) revert ZkMinimalAccount__NotEnoughBalance();
        require(address(this).balance > totalRequiredBalance, ZkMinimalAccount__NotEnoughBalance());

        // Check the signature
        bytes32 txHash = _transaction.encodeHash();
        bytes32 convertedHash = MessageHashUtils.toEthSignedMessageHash(txHash);
        address signer = ECDSA.recover(convertedHash, _transaction.signature);
        bool isValidSignature = signer == owner();

        if (isValidSignature) {
            magic = ACCOUNT_VALIDATION_SUCCESS_MAGIC;
        } else {
            magic = bytes4(0);
        }

        // Return the magic number
        return magic;
    }

    function executeTransaction(bytes32, /*_txHash*/ bytes32, /*_suggestedSignedHash*/ Transaction memory _transaction)
        external
        payable
        requireFromBootLoaderOrOwner
    {
        address to = address(uint160(_transaction.to));
        uint128 value = Utils.safeCastToU128(_transaction.value);
        bytes memory data = _transaction.data;

        if (to == address(DEPLOYER_SYSTEM_CONTRACT)) {
            uint32 gas = Utils.safeCastToU32(gasleft());
            SystemContractsCaller.systemCallWithPropagatedRevert(gas, to, value, data);
        } else {
            bool success;

            assembly {
                success := call(gas(), to, value, add(data, 0x20), mload(data), 0, 0)
            }
            require(success, ZkMinimalAccount__ExecutionFailed());
        }
    }

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

    /**
     * INTERNAL FUNCTIONS
     */
}
