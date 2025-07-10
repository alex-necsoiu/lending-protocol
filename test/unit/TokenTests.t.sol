// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { BaseTest } from "./BaseTest.t.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { StakeAaveToken } from "../../src/tokens/StakeAaveToken.sol";

/**
 * @title TokenTests
 * @author Alex Necsoiu
 * @notice Tests for rebasing token functionality
 * @dev Tests the StakeAave token rebasing mechanism and ERC20 compliance
 */
contract TokenTests is BaseTest {
    
    function test_TokenInitialState() public view {
        // Check token names and symbols
        assertEq(saUSDC.name(), "Stake Aave USDC", "saUSDC name incorrect");
        assertEq(saUSDC.symbol(), "saUSDC", "saUSDC symbol incorrect");
        assertEq(saUSDC.decimals(), 18, "saUSDC decimals incorrect");
        
        assertEq(saETH.name(), "Stake Aave ETH", "saETH name incorrect");
        assertEq(saETH.symbol(), "saETH", "saETH symbol incorrect");
        
        assertEq(saMATIC.name(), "Stake Aave MATIC", "saMATIC name incorrect");
        assertEq(saMATIC.symbol(), "saMATIC", "saMATIC symbol incorrect");
        
        // Check underlying assets
        assertEq(saUSDC.asset(), address(usdc), "saUSDC underlying asset incorrect");
        assertEq(saETH.asset(), address(weth), "saETH underlying asset incorrect");
        assertEq(saMATIC.asset(), address(matic), "saMATIC underlying asset incorrect");
        
        // Check initial supply is zero
        assertEq(saUSDC.totalSupply(), 0, "saUSDC initial supply should be 0");
        assertEq(saUSDC.totalAssets(), 0, "saUSDC initial assets should be 0");
    }

    function test_DirectTokenDeposit() public {
        uint256 depositAmount = 1000e6; // 1000 USDC
        
        // Approve and deposit directly to token
        vm.startPrank(user1);
        usdc.approve(address(saUSDC), depositAmount);
        uint256 shares = saUSDC.deposit(depositAmount, user1);
        vm.stopPrank();
        
        // First deposit should be 1:1 ratio
        assertEq(shares, depositAmount, "First deposit should be 1:1 ratio");
        assertEq(saUSDC.balanceOf(user1), depositAmount, "User should have correct shares");
        assertEq(saUSDC.totalAssets(), depositAmount, "Total assets should equal deposit");
        assertEq(saUSDC.totalSupply(), depositAmount, "Total supply should equal deposit");
    }

    function test_DirectTokenRedeem() public {
        uint256 depositAmount = 1000e6;
        
        // Deposit first
        vm.startPrank(user1);
        usdc.approve(address(saUSDC), depositAmount);
        saUSDC.deposit(depositAmount, user1);
        
        // Redeem half
        uint256 redeemShares = depositAmount / 2;
        uint256 initialBalance = usdc.balanceOf(user1);
        uint256 assets = saUSDC.redeem(redeemShares, user1, user1);
        vm.stopPrank();
        
        assertEq(assets, redeemShares, "Should redeem 1:1 without interest");
        assertEq(usdc.balanceOf(user1), initialBalance + redeemShares, "User should receive correct assets");
        assertEq(saUSDC.balanceOf(user1), redeemShares, "User should have remaining shares");
    }

    function test_ConversionFunctions() public {
        uint256 depositAmount = 1000e6;
        
        // Test conversion when no supply exists
        assertEq(saUSDC.convertToShares(depositAmount), depositAmount, "Initial conversion should be 1:1");
        assertEq(saUSDC.convertToAssets(depositAmount), depositAmount, "Initial conversion should be 1:1");
        
        // Deposit to establish supply
        _deposit(user1, address(usdc), depositAmount);
        
        // Test conversion with supply
        assertEq(saUSDC.convertToShares(depositAmount), depositAmount, "Conversion should remain 1:1");
        assertEq(saUSDC.convertToAssets(depositAmount), depositAmount, "Conversion should remain 1:1");
        
        // Add interest to change ratio
        uint256 interestAmount = 100e6; // 10% interest
        usdc.mint(owner, interestAmount);
        _simulateInterest(address(usdc), interestAmount);
        
        // Now conversions should reflect the interest
        uint256 expectedShares = (depositAmount * depositAmount) / (depositAmount + interestAmount);
        uint256 actualShares = saUSDC.convertToShares(depositAmount);
        assertApproxEqRel(actualShares, expectedShares, "Shares conversion after interest incorrect");
        
        uint256 expectedAssets = (depositAmount * (depositAmount + interestAmount)) / depositAmount;
        uint256 actualAssets = saUSDC.convertToAssets(depositAmount);
        assertEq(actualAssets, expectedAssets, "Assets conversion after interest incorrect");
    }

    function test_InterestAccrualMechanism() public {
        uint256 depositAmount = 1000e6;
        uint256 interestAmount = 50e6; // 5% interest
        
        // User deposits through lending engine
        _deposit(user1, address(usdc), depositAmount);
        uint256 initialShares = saUSDC.balanceOf(user1);
        
        // Check initial state
        assertEq(saUSDC.totalAssets(), depositAmount, "Initial total assets incorrect");
        assertEq(saUSDC.totalSupply(), depositAmount, "Initial total supply incorrect");
        
        // Accrue interest through lending engine (not directly to token)
        usdc.mint(owner, interestAmount);
        _simulateInterest(address(usdc), interestAmount);
        
        // Check that assets increased but supply stayed the same
        assertEq(saUSDC.totalAssets(), depositAmount + interestAmount, "Total assets should increase");
        assertEq(saUSDC.totalSupply(), depositAmount, "Total supply should remain the same");
        assertEq(saUSDC.balanceOf(user1), initialShares, "User shares should remain the same");
        
        // User should be able to redeem more assets than they deposited
        uint256 redeemableAssets = saUSDC.convertToAssets(initialShares);
        assertEq(redeemableAssets, depositAmount + interestAmount, "User should get all assets including interest");
    }

    function test_MultipleUsersRebasingShares() public {
        uint256 deposit1 = 600e6; // User1 deposits 600 USDC
        uint256 deposit2 = 400e6; // User2 deposits 400 USDC
        uint256 interestAmount = 100e6; // 100 USDC interest added
        
        // Both users deposit
        _deposit(user1, address(usdc), deposit1);
        _deposit(user2, address(usdc), deposit2);
        
        uint256 shares1 = saUSDC.balanceOf(user1);
        uint256 shares2 = saUSDC.balanceOf(user2);
        
        // Add interest
        usdc.mint(owner, interestAmount);
        _simulateInterest(address(usdc), interestAmount);
        
        // Shares should remain the same
        assertEq(saUSDC.balanceOf(user1), shares1, "User1 shares should not change");
        assertEq(saUSDC.balanceOf(user2), shares2, "User2 shares should not change");
        
        // But each share should be worth more
        uint256 assets1 = saUSDC.convertToAssets(shares1);
        uint256 assets2 = saUSDC.convertToAssets(shares2);
        
        // Calculate expected distribution (proportional to original deposits)
        uint256 totalDeposits = deposit1 + deposit2;
        uint256 expectedAssets1 = deposit1 + (interestAmount * deposit1) / totalDeposits;
        uint256 expectedAssets2 = deposit2 + (interestAmount * deposit2) / totalDeposits;
        
        assertApproxEqRel(assets1, expectedAssets1, "User1 asset value incorrect");
        assertApproxEqRel(assets2, expectedAssets2, "User2 asset value incorrect");
        
        // Total should equal all deposits plus interest
        assertEq(assets1 + assets2, totalDeposits + interestAmount, "Total assets should equal deposits + interest");
    }

    function test_TokenTransfers() public {
        uint256 depositAmount = 1000e6;
        uint256 transferAmount = 300e6;
        
        // User1 deposits and gets shares
        _deposit(user1, address(usdc), depositAmount);
        uint256 initialShares = saUSDC.balanceOf(user1);
        
        // Transfer shares to user2
        vm.prank(user1);
        saUSDC.transfer(user2, transferAmount);
        
        // Check balances
        assertEq(saUSDC.balanceOf(user1), initialShares - transferAmount, "User1 balance after transfer incorrect");
        assertEq(saUSDC.balanceOf(user2), transferAmount, "User2 balance after transfer incorrect");
        
        // Add interest
        uint256 interestAmount = 100e6;
        usdc.mint(owner, interestAmount);
        _simulateInterest(address(usdc), interestAmount);
        
        // Both users should benefit proportionally from interest
        uint256 user1Assets = saUSDC.convertToAssets(saUSDC.balanceOf(user1));
        uint256 user2Assets = saUSDC.convertToAssets(saUSDC.balanceOf(user2));
        
        // Check proportional distribution
        uint256 totalAssets = user1Assets + user2Assets;
        assertEq(totalAssets, depositAmount + interestAmount, "Total should equal deposits plus interest");
        
        uint256 user1Proportion = (user1Assets * 10000) / totalAssets;
        uint256 expectedUser1Proportion = ((initialShares - transferAmount) * 10000) / initialShares;
        assertApproxEqRel(user1Proportion, expectedUser1Proportion, "User1 proportion incorrect");
    }

    function test_RevertOnUnauthorizedAccrueInterest() public {
        uint256 interestAmount = 100e6;
        usdc.mint(user1, interestAmount);
        
        vm.startPrank(user1);
        usdc.approve(address(saUSDC), interestAmount);
        
        // Only lending engine should be able to accrue interest
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("StakeAaveToken__NotLendingEngine()"))));
        saUSDC.accrueInterest(interestAmount);
        vm.stopPrank();
    }

    function test_RevertOnZeroAmounts() public {
        vm.startPrank(user1);
        
        // Zero deposit should revert
        usdc.approve(address(saUSDC), 0);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("StakeAaveToken__NeedsMoreThanZero()"))));
        saUSDC.deposit(0, user1);
        
        // Zero redeem should revert
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("StakeAaveToken__NeedsMoreThanZero()"))));
        saUSDC.redeem(0, user1, user1);
        
        vm.stopPrank();
    }

    function test_ERC20Compliance() public {
        uint256 depositAmount = 1000e6;
        uint256 approvalAmount = 500e6;
        
        // Test approval and allowance
        vm.prank(user1);
        saUSDC.approve(user2, approvalAmount);
        assertEq(saUSDC.allowance(user1, user2), approvalAmount, "Allowance not set correctly");
        
        // Deposit to get some shares
        _deposit(user1, address(usdc), depositAmount);
        
        // Test transferFrom
        vm.prank(user2);
        saUSDC.transferFrom(user1, user3, approvalAmount);
        
        assertEq(saUSDC.balanceOf(user3), approvalAmount, "TransferFrom failed");
        assertEq(saUSDC.allowance(user1, user2), 0, "Allowance should be reduced to 0");
        
        // Test increase/decrease allowance
        vm.prank(user1);
        saUSDC.approve(user2, approvalAmount);
        
        vm.prank(user1);
        saUSDC.approve(user2, 0); // Reset allowance
        assertEq(saUSDC.allowance(user1, user2), 0, "Allowance should be 0 after reset");
    }

    function test_RebasingDuringActivePositions() public {
        // Simulate a real-world scenario with multiple rebasing events
        uint256 deposit1 = 1000e6;
        uint256 deposit2 = 500e6;
        
        // Initial deposits
        _deposit(user1, address(usdc), deposit1);
        
        // First interest accrual (5%)
        uint256 interest1 = 50e6;
        usdc.mint(owner, interest1);
        _simulateInterest(address(usdc), interest1);
        
        // User2 deposits after first interest (should get fewer shares)
        _deposit(user2, address(usdc), deposit2);
        
        uint256 shares1 = saUSDC.balanceOf(user1);
        uint256 shares2 = saUSDC.balanceOf(user2);
        
        // Second interest accrual (5% on new total)
        uint256 currentAssets = saUSDC.totalAssets();
        uint256 interest2 = currentAssets * 5 / 100;
        usdc.mint(owner, interest2);
        _simulateInterest(address(usdc), interest2);
        
        // Check that each user gets proportional interest
        uint256 finalAssets1 = saUSDC.convertToAssets(shares1);
        uint256 finalAssets2 = saUSDC.convertToAssets(shares2);
        
        // User1 should have more assets than they deposited
        assertGt(finalAssets1, deposit1, "User1 should have earned interest");
        
        // User2 should also have more than they deposited, but less growth than User1
        assertGt(finalAssets2, deposit2, "User2 should have earned some interest");
        assertLt(finalAssets2 - deposit2, finalAssets1 - deposit1, "User1 should have earned more interest");
        
        // Total should equal all deposits plus all interest (allow for 1 wei rounding error)
        assertApproxEqAbs(finalAssets1 + finalAssets2, deposit1 + deposit2 + interest1 + interest2, 1, 
               "Total should equal all deposits plus interest");
    }
}
