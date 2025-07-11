// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { LendingEngine } from "../src/LendingEngine.sol";
import { IStakeAaveToken } from "../src/interfaces/IStakeAaveToken.sol";

/**
 * @title InteractWithProtocol
 * @notice Script to interact with the deployed lending protocol
 */
contract InteractWithProtocol is Script {
    // Deployed contract addresses (from deployment)
    LendingEngine constant LENDING_ENGINE = LendingEngine(0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9);
    IERC20 constant USDC = IERC20(0x5FbDB2315678afecb367f032d93F642f64180aa3);
    IStakeAaveToken constant SA_USDC = IStakeAaveToken(0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9);
    
    // Anvil default account
    address constant USER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 constant PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function run() external {
        console.log("\n=== TESTING DEPLOYED LENDING PROTOCOL ===");
        
        vm.startBroadcast(PRIVATE_KEY);
        
        // Step 1: Get some USDC tokens (mint from mock)
        console.log("\n--- Step 1: Getting USDC tokens ---");
        (bool success,) = address(USDC).call(abi.encodeWithSignature("mint(address,uint256)", USER, 10000e6));
        require(success, "Mint failed");
        uint256 userBalance = USDC.balanceOf(USER);
        console.log("User USDC balance:", userBalance);
        
        // Step 2: Deposit USDC into the protocol
        console.log("\n--- Step 2: Depositing 1000 USDC ---");
        uint256 depositAmount = 1000e6;
        USDC.approve(address(LENDING_ENGINE), depositAmount);
        uint256 sharesReceived = LENDING_ENGINE.deposit(address(USDC), depositAmount);
        console.log("Shares received:", sharesReceived);
        console.log("User saUSDC balance:", SA_USDC.balanceOf(USER));
        console.log("Protocol total assets:", SA_USDC.totalAssets());
        
        // Step 3: Check share price (should be 1.0 initially)
        console.log("\n--- Step 3: Checking share price ---");
        uint256 sharePrice = LENDING_ENGINE.getSharePrice(address(USDC));
        console.log("Share price:", sharePrice);
        
        // Step 4: Simulate interest accrual
        console.log("\n--- Step 4: Accruing 50 USDC interest ---");
        uint256 interestAmount = 50e6;
        // Mint interest to user, then approve and transfer to LendingEngine
        (bool success2,) = address(USDC).call(abi.encodeWithSignature("mint(address,uint256)", USER, interestAmount));
        require(success2, "Interest mint failed");
        USDC.approve(address(LENDING_ENGINE), interestAmount);
        LENDING_ENGINE.simulateInterest(address(USDC), interestAmount);
        console.log("New total assets:", SA_USDC.totalAssets());
        console.log("New share price:", LENDING_ENGINE.getSharePrice(address(USDC)));
        
        // Step 5: Check user's asset value (should include interest)
        console.log("\n--- Step 5: Checking user's value ---");
        uint256 userShares = SA_USDC.balanceOf(USER);
        uint256 userAssetValue = SA_USDC.convertToAssets(userShares);
        console.log("User shares:", userShares);
        console.log("User asset value:", userAssetValue);
        console.log("Interest earned:", userAssetValue - depositAmount);
        
        // Step 6: Redeem half the shares
        console.log("\n--- Step 6: Redeeming half shares ---");
        uint256 redeemShares = userShares / 2;
        SA_USDC.approve(address(LENDING_ENGINE), redeemShares);
        uint256 assetsReceived = LENDING_ENGINE.redeem(address(USDC), redeemShares);
        console.log("Assets received:", assetsReceived);
        console.log("Remaining user shares:", SA_USDC.balanceOf(USER));
        console.log("User USDC balance after redeem:", USDC.balanceOf(USER));
        
        vm.stopBroadcast();
        
        console.log("\n=== PROTOCOL TEST COMPLETED SUCCESSFULLY ===");
    }
}
