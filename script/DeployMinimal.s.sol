// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import {Script, console2} from "forge-std/Script.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract DeployMinimal is Script {
    MinimalAccount minimalAccount;
    HelperConfig helperConfig;

    function run() public {}

    function deployMinimalAccount() public returns(HelperConfig, MinimalAccount) {
        helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast(config.account);
        minimalAccount = new MinimalAccount(config.entryPoint);
        minimalAccount.transferOwnership(msg.sender);
        vm.stopBroadcast();

        return (helperConfig, minimalAccount);
    }
}