// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";

contract HelperConfig is Script {
    /**
     * ERRORS
     */
    error HelperConfig__InvalidChainId();

    /**
     * TYPES
     */

    struct  NetworkConfig {
        address entryPoint;
        address account;
    }

    /**
     * STATE VARIABLES
     */

    uint256 private constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 private constant ZKSYNC_SEPOLIA_CHAIN_ID = 300;
    uint256 private constant LOCAL_CHAIN_ID = 31337;
    address constant BURNER_WALLET = 0xEe56334d234E8F9767444E33dCC45A993769117d;
    address constant FOUNDRY_DEFAULT_WALLET = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    NetworkConfig public localNetworkConfig;
    mapping (uint256 chainId => NetworkConfig) public networkConfigs;

    /**
     * FUNCTIONS
     */
    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaNetworkConfig();
    }

    function getConfig() public view returns(NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(uint256 chainId) public view returns(NetworkConfig memory) {
        if(chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthNetworkConfig();
        } else if(networkConfigs[chainId].account != address(0)) {
            return networkConfigs[chainId];
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    /**
     * CONFIGS
     */

    function getEthMainNetworkConfig() public pure returns(NetworkConfig memory) {
        // this is v7
        return NetworkConfig({entryPoint: 0x0000000071727De22E5E9d8BAf0edAc6f37da032, account: BURNER_WALLET});
    }

    function getEthSepoliaNetworkConfig() public pure returns(NetworkConfig memory) {
        return NetworkConfig({entryPoint: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789, account: BURNER_WALLET});
    }

    function getZkSyncNetworkConfig() public pure returns(NetworkConfig memory) {
        return NetworkConfig({entryPoint: address(0), account: BURNER_WALLET});
    }

    function getOrCreateAnvilEthNetworkConfig() public view returns(NetworkConfig memory) {
        if(localNetworkConfig.account != address(0)) return localNetworkConfig;

        // deploy a mock entry point contract
        return NetworkConfig({entryPoint: address(0), account: FOUNDRY_DEFAULT_WALLET});
    }
}