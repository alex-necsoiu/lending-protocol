// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { LendingEngine } from "../src/LendingEngine.sol";
import { StakeAaveUSDC } from "../src/tokens/StakeAaveUSDC.sol";
import { StakeAaveETH } from "../src/tokens/StakeAaveETH.sol";
import { StakeAaveMATIC } from "../src/tokens/StakeAaveMATIC.sol";
import { MockERC20 } from "../src/mocks/MockERC20.sol";
import { MockWETH } from "../src/mocks/MockWETH.sol";

/**
 * @title DeployLending
 * @author Alex Necsoiu
 * @notice Deployment script for the lending protocol
 * @dev Deploys all core contracts and sets up initial configuration
 */
contract DeployLending is Script {
    // Network configuration
    struct NetworkConfig {
        address usdc;
        address weth;
        address matic;
        uint256 deployerKey;
    }

    // Deployment addresses
    struct Contracts {
        LendingEngine lendingEngine;
        StakeAaveUSDC saUSDC;
        StakeAaveETH saETH;
        StakeAaveMATIC saMATIC;
        address usdc;
        address weth;
        address matic;
    }

    // --- Constants ---
    uint256 public constant DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    // --- Main deployment function ---
    function run() external returns (Contracts memory contracts) {
        NetworkConfig memory config = getNetworkConfig();
        
        vm.startBroadcast(config.deployerKey);
        contracts = deployContracts(config);
        setupProtocol(contracts);
        vm.stopBroadcast();

        logDeployment(contracts);
        return contracts;
    }

    /**
     * @notice Deploy all core contracts
     * @param config Network configuration
     * @return contracts Deployed contract addresses
     */
    function deployContracts(NetworkConfig memory config) internal returns (Contracts memory contracts) {
        // Deploy or use existing tokens
        contracts.usdc = config.usdc;
        contracts.weth = config.weth;
        contracts.matic = config.matic;

        // If we're on a local network, deploy mock tokens
        if (contracts.usdc == address(0)) {
            contracts.usdc = address(new MockERC20("USD Coin", "USDC", 6));
            console.log("Deployed Mock USDC:", contracts.usdc);
        }

        if (contracts.weth == address(0)) {
            contracts.weth = address(new MockWETH());
            console.log("Deployed Mock WETH:", contracts.weth);
        }

        if (contracts.matic == address(0)) {
            contracts.matic = address(new MockERC20("Polygon", "MATIC", 18));
            console.log("Deployed Mock MATIC:", contracts.matic);
        }

        // Deploy LendingEngine
        contracts.lendingEngine = new LendingEngine(msg.sender);
        console.log("Deployed LendingEngine:", address(contracts.lendingEngine));

        // Deploy protocol tokens with deployer as initial owner
        contracts.saUSDC = new StakeAaveUSDC(contracts.usdc, msg.sender);
        contracts.saETH = new StakeAaveETH(contracts.weth, msg.sender);
        contracts.saMATIC = new StakeAaveMATIC(contracts.matic, msg.sender);

        console.log("Deployed saUSDC:", address(contracts.saUSDC));
        console.log("Deployed saETH:", address(contracts.saETH));
        console.log("Deployed saMATIC:", address(contracts.saMATIC));
    }

    /**
     * @notice Setup protocol configuration
     * @param contracts Deployed contracts
     */
    function setupProtocol(Contracts memory contracts) internal {
        // Set lending engine on protocol tokens
        contracts.saUSDC.setLendingEngine(address(contracts.lendingEngine));
        contracts.saETH.setLendingEngine(address(contracts.lendingEngine));
        contracts.saMATIC.setLendingEngine(address(contracts.lendingEngine));

        // Add assets to lending engine
        contracts.lendingEngine.addAsset(contracts.usdc, address(contracts.saUSDC));
        contracts.lendingEngine.addAsset(contracts.weth, address(contracts.saETH));
        contracts.lendingEngine.addAsset(contracts.matic, address(contracts.saMATIC));

        // Transfer ownership of tokens to lending engine for production
        contracts.saUSDC.transferOwnership(address(contracts.lendingEngine));
        contracts.saETH.transferOwnership(address(contracts.lendingEngine));
        contracts.saMATIC.transferOwnership(address(contracts.lendingEngine));

        console.log("Protocol setup completed");
    }

    /**
     * @notice Get network-specific configuration
     * @return config Network configuration
     */
    function getNetworkConfig() internal view returns (NetworkConfig memory config) {
        if (block.chainid == 31337) {
            // Local Anvil network - use mock tokens
            config = NetworkConfig({
                usdc: address(0), // Will deploy mock
                weth: address(0), // Will deploy mock
                matic: address(0), // Will deploy mock
                deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
            });
        } else if (block.chainid == 1) {
            // Mainnet - using mock addresses for simplicity
            config = NetworkConfig({
                usdc: address(0), // Will deploy mock
                weth: address(0), // Will deploy mock
                matic: address(0), // Will deploy mock
                deployerKey: vm.envUint("PRIVATE_KEY")
            });
        } else if (block.chainid == 11155111) {
            // Sepolia testnet
            config = NetworkConfig({
                usdc: address(0), // Will deploy mock
                weth: address(0), // Will deploy mock  
                matic: address(0), // Will deploy mock
                deployerKey: vm.envUint("PRIVATE_KEY")
            });
        } else {
            revert("Unsupported network");
        }
    }

    /**
     * @notice Log deployment information
     * @param contracts Deployed contracts
     */
    function logDeployment(Contracts memory contracts) internal view {
        console.log("\n=== LENDING PROTOCOL DEPLOYMENT ===");
        console.log("Network:", block.chainid);
        console.log("Deployer:", msg.sender);
        console.log("\n--- Core Contracts ---");
        console.log("LendingEngine:", address(contracts.lendingEngine));
        console.log("\n--- Protocol Tokens ---");
        console.log("saUSDC:", address(contracts.saUSDC));
        console.log("saETH:", address(contracts.saETH));
        console.log("saMATIC:", address(contracts.saMATIC));
        console.log("\n--- Underlying Assets ---");
        console.log("USDC:", contracts.usdc);
        console.log("WETH:", contracts.weth);
        console.log("MATIC:", contracts.matic);
        console.log("=====================================\n");
    }
}
