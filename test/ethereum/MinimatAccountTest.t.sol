// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {MinimalAccount, IEntryPoint} from "src/ethereum/MinimalAccount.sol";
import {DeployMinimal} from "script/DeployMinimal.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOperation, PackedUserOperation, MessageHashUtils} from "script/SendPackedUserOperation.s.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MinimalAccountTest is Test {
    using MessageHashUtils for bytes32;
    MinimalAccount minimalAccount;
    DeployMinimal deployMinimal;
    HelperConfig helperConfig;
    SendPackedUserOperation sendPackedUserOperation;
    ERC20Mock usdc;
    uint256 constant AMOUNT = 1e18;
    address randomUser = makeAddr("randomUser");

    function setUp() public {
        deployMinimal = new DeployMinimal();
        (helperConfig, minimalAccount) = deployMinimal.deployMinimalAccount();
        usdc = new ERC20Mock();
        sendPackedUserOperation = new SendPackedUserOperation();
    }

    /**
     * Mint USDC
     * msg.sender minimal account
     * approves some amount
     * USDC contract
     * comes from the entry point
     */
    function testOwnerCanExecuteCommand() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        // Act
        vm.prank(minimalAccount.owner());
        minimalAccount.execute(dest, value, functionData);

        // Assert
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }

    function testNotOwnerCanNotExecuteCommand() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        // Act
        vm.prank(randomUser);
        vm.expectRevert(MinimalAccount.MinimalAccount__NotEntryPointOrOwner.selector);
        minimalAccount.execute(dest, value, functionData);

        // Assert
        // assertEq(usdc.balanceOf(address(minimalAccount)), 0);
    }

    function testRecoverOperation() public {
         // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOperation = sendPackedUserOperation.generateSignedUserOperation(executeCallData, helperConfig.getConfig());

        bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOperation);

        // Act
        address actualSigner =  ECDSA.recover(userOperationHash.toEthSignedMessageHash(), packedUserOperation.signature);

        // Assert
        assertEq(actualSigner, minimalAccount.owner());
    }
}
