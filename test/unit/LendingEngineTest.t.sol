// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { BaseTest } from "./BaseTest.t.sol";
import { console } from "forge-std/console.sol";
import { Vm } from "forge-std/Vm.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ILendingEngine } from "../../src/interfaces/ILendingEngine.sol";

/**
 * @title LendingEngineTest
 * @author Alex Necsoiu
 * @notice Comprehensive tests for the LendingEngine contract
 * @dev Tests all core functionality: deposits, redemptions, and interest accrual
 */
contract LendingEngineTest is BaseTest {
    
    function test_InitialState() public view {
        // Check that all assets are supported
        assertTrue(lendingEngine.isAssetSupported(address(usdc)), "USDC should be supported");
        assertTrue(lendingEngine.isAssetSupported(address(weth)), "WETH should be supported");
        assertTrue(lendingEngine.isAssetSupported(address(matic)), "MATIC should be supported");

        // Check that protocol tokens are set correctly
        ILendingEngine.AssetInfo memory usdcInfo = lendingEngine.getAssetInfo(address(usdc));
        assertEq(address(usdcInfo.token), address(saUSDC), "USDC protocol token mismatch");
        
        ILendingEngine.AssetInfo memory wethInfo = lendingEngine.getAssetInfo(address(weth));
        assertEq(address(wethInfo.token), address(saETH), "WETH protocol token mismatch");
        
        ILendingEngine.AssetInfo memory maticInfo = lendingEngine.getAssetInfo(address(matic));
        assertEq(address(maticInfo.token), address(saMATIC), "MATIC protocol token mismatch");

        // Check initial balances are zero
        assertEq(saUSDC.totalAssets(), 0, "Initial USDC assets should be 0");
        assertEq(saETH.totalAssets(), 0, "Initial WETH assets should be 0");
        assertEq(saMATIC.totalAssets(), 0, "Initial MATIC assets should be 0");
    }

    function test_DepositUSDC() public {
        uint256 depositAmount = 1000e6; // 1000 USDC
        
        // Record initial state
        uint256 initialBalance = usdc.balanceOf(user1);
        uint256 initialShares = saUSDC.balanceOf(user1);
        
        // Perform deposit
        _deposit(user1, address(usdc), depositAmount);
        
        // Verify state changes
        assertEq(usdc.balanceOf(user1), initialBalance - depositAmount, "User USDC balance incorrect");
        assertEq(saUSDC.balanceOf(user1), initialShares + depositAmount, "User saUSDC balance incorrect");
        assertEq(saUSDC.totalAssets(), depositAmount, "Total USDC assets incorrect");
        assertEq(saUSDC.totalAssets(), depositAmount, "saUSDC total assets incorrect");
    }

    function test_DepositWETH() public {
        uint256 depositAmount = 10e18; // 10 WETH
        
        // Record initial state
        uint256 initialBalance = weth.balanceOf(user1);
        uint256 initialShares = saETH.balanceOf(user1);
        
        // Perform deposit
        _deposit(user1, address(weth), depositAmount);
        
        // Verify state changes
        assertEq(weth.balanceOf(user1), initialBalance - depositAmount, "User WETH balance incorrect");
        assertEq(saETH.balanceOf(user1), initialShares + depositAmount, "User saETH balance incorrect");
        assertEq(saETH.totalAssets(), depositAmount, "Total WETH assets incorrect");
    }

    function test_DepositMATIC() public {
        uint256 depositAmount = 1000e18; // 1000 MATIC
        
        // Record initial state
        uint256 initialBalance = matic.balanceOf(user1);
        uint256 initialShares = saMATIC.balanceOf(user1);
        
        // Perform deposit
        _deposit(user1, address(matic), depositAmount);
        
        // Verify state changes
        assertEq(matic.balanceOf(user1), initialBalance - depositAmount, "User MATIC balance incorrect");
        assertEq(saMATIC.balanceOf(user1), initialShares + depositAmount, "User saMATIC balance incorrect");
        assertEq(saMATIC.totalAssets(), depositAmount, "Total MATIC assets incorrect");
    }

    function test_MultipleDeposits() public {
        uint256 amount1 = 500e6; // 500 USDC
        uint256 amount2 = 300e6; // 300 USDC
        
        // First deposit
        _deposit(user1, address(usdc), amount1);
        assertEq(saUSDC.balanceOf(user1), amount1, "First deposit shares incorrect");
        
        // Second deposit by same user
        _deposit(user1, address(usdc), amount2);
        assertEq(saUSDC.balanceOf(user1), amount1 + amount2, "Total shares after second deposit incorrect");
        
        // Deposit by different user
        uint256 amount3 = 200e6; // 200 USDC
        _deposit(user2, address(usdc), amount3);
        assertEq(saUSDC.balanceOf(user2), amount3, "User2 shares incorrect");
        
        // Check total assets
        assertEq(saUSDC.totalAssets(), amount1 + amount2 + amount3, "Total assets incorrect");
    }

    function test_RedeemBasic() public {
        uint256 depositAmount = 1000e6; // 1000 USDC
        
        // First deposit
        _deposit(user1, address(usdc), depositAmount);
        
        // Redeem half
        uint256 redeemShares = depositAmount / 2;
        uint256 initialBalance = usdc.balanceOf(user1);
        
        _redeem(user1, address(usdc), redeemShares);
        
        // Verify state
        assertEq(usdc.balanceOf(user1), initialBalance + redeemShares, "User USDC balance after redeem incorrect");
        assertEq(saUSDC.balanceOf(user1), redeemShares, "User saUSDC balance after redeem incorrect");
        assertEq(saUSDC.totalAssets(), redeemShares, "Total assets after redeem incorrect");
    }

    function test_InterestAccrual() public {
        uint256 depositAmount = 1000e6; // 1000 USDC
        uint256 interestAmount = 50e6; // 50 USDC interest
        
        // Deposit by user1
        _deposit(user1, address(usdc), depositAmount);
        uint256 initialShares = saUSDC.balanceOf(user1);
        
        // Add interest (mint to owner first)
        usdc.mint(owner, interestAmount);
        
        // Simulate interest accrual
        _simulateInterest(address(usdc), interestAmount);
        
        // Verify interest was added
        assertEq(saUSDC.totalAssets(), depositAmount + interestAmount, "Total assets after interest incorrect");
        assertEq(saUSDC.totalAssets(), depositAmount + interestAmount, "saUSDC total assets after interest incorrect");
        
        // User should have same shares but they're now worth more
        assertEq(saUSDC.balanceOf(user1), initialShares, "User shares should remain the same");
        
        // When user redeems, they should get more assets than they deposited
        uint256 userAssets = saUSDC.convertToAssets(initialShares);
        assertEq(userAssets, depositAmount + interestAmount, "User should receive all interest");
    }

    function test_InterestDistribution() public {
        uint256 deposit1 = 600e6; // 600 USDC
        uint256 deposit2 = 400e6; // 400 USDC
        uint256 interestAmount = 100e6; // 100 USDC interest
        
        // Two users deposit
        _deposit(user1, address(usdc), deposit1);
        _deposit(user2, address(usdc), deposit2);
        
        uint256 shares1 = saUSDC.balanceOf(user1);
        uint256 shares2 = saUSDC.balanceOf(user2);
        
        // Add interest
        usdc.mint(owner, interestAmount);
        _simulateInterest(address(usdc), interestAmount);
        
        // Calculate expected distribution (proportional to deposits)
        uint256 expectedAssets1 = deposit1 + (interestAmount * deposit1) / (deposit1 + deposit2);
        uint256 expectedAssets2 = deposit2 + (interestAmount * deposit2) / (deposit1 + deposit2);
        
        // Verify distribution
        uint256 actualAssets1 = saUSDC.convertToAssets(shares1);
        uint256 actualAssets2 = saUSDC.convertToAssets(shares2);
        
        assertApproxEqRel(actualAssets1, expectedAssets1, "User1 interest distribution incorrect");
        assertApproxEqRel(actualAssets2, expectedAssets2, "User2 interest distribution incorrect");
    }

    function test_SharePriceIncrease() public {
        uint256 depositAmount = 1000e6; // 1000 USDC
        uint256 interestAmount = 100e6; // 100 USDC (10% yield)
        
        // Initial share price should be 1.0
        assertEq(lendingEngine.getSharePrice(address(usdc)), PRECISION, "Initial share price should be 1.0");
        
        // Deposit
        _deposit(user1, address(usdc), depositAmount);
        assertEq(lendingEngine.getSharePrice(address(usdc)), PRECISION, "Share price should remain 1.0 after deposit");
        
        // Add interest
        usdc.mint(owner, interestAmount);
        _simulateInterest(address(usdc), interestAmount);
        
        // Share price should increase
        uint256 expectedPrice = PRECISION * (depositAmount + interestAmount) / depositAmount; // 1.1
        assertEq(lendingEngine.getSharePrice(address(usdc)), expectedPrice, "Share price should increase after interest");
        
        // New depositor should get fewer shares for same amount
        uint256 newDepositAmount = 1000e6;
        uint256 initialShares = saUSDC.balanceOf(user2);
        _deposit(user2, address(usdc), newDepositAmount);
        
        uint256 newShares = saUSDC.balanceOf(user2) - initialShares;
        uint256 expectedShares = (newDepositAmount * PRECISION) / expectedPrice;
        
        assertApproxEqRel(newShares, expectedShares, "New depositor should get fewer shares");
    }

    function test_RevertOnUnsupportedAsset() public {
        // Create a fake token
        address fakeToken = makeAddr("fakeToken");
        
        // Should revert when trying to deposit unsupported asset
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("LendingEngine__AssetNotSupported(address)")), fakeToken));
        vm.prank(user1);
        lendingEngine.deposit(fakeToken, 100);
    }

    function test_RevertOnZeroDeposit() public {
        vm.expectRevert(bytes4(keccak256("LendingEngine__NeedsMoreThanZero()")));
        vm.prank(user1);
        lendingEngine.deposit(address(usdc), 0);
    }

    function test_RevertOnInsufficientBalance() public {
        uint256 excessiveAmount = USDC_INITIAL + 1; // More than user has
        
        vm.startPrank(user1);
        usdc.approve(address(lendingEngine), excessiveAmount);
        
        vm.expectRevert(bytes4(keccak256("LendingEngine__InsufficientBalance()")));
        lendingEngine.deposit(address(usdc), excessiveAmount);
        vm.stopPrank();
    }

    function test_RevertOnInsufficientShares() public {
        uint256 depositAmount = 1000e6;
        _deposit(user1, address(usdc), depositAmount);
        
        uint256 excessiveShares = saUSDC.balanceOf(user1) + 1;
        
        vm.expectRevert(bytes4(keccak256("LendingEngine__InsufficientBalance()")));
        vm.prank(user1);
        lendingEngine.redeem(address(usdc), excessiveShares);
    }

    function test_FullProtocolFlow() public {
        console.log("\n=== TESTING FULL PROTOCOL FLOW ===");
        
        // 1. Multiple users deposit different assets
        uint256 usdcDeposit = 1000e6;
        uint256 wethDeposit = 5e18;
        uint256 maticDeposit = 2000e18;
        
        _deposit(user1, address(usdc), usdcDeposit);
        _deposit(user2, address(weth), wethDeposit);
        _deposit(user3, address(matic), maticDeposit);
        
        console.log("Initial deposits completed");
        _logProtocolState();
        
        // 2. Simulate interest accrual for all assets
        uint256 usdcInterest = 50e6; // 5% on USDC
        uint256 wethInterest = 0.25e18; // 5% on WETH
        uint256 maticInterest = 100e18; // 5% on MATIC
        
        usdc.mint(owner, usdcInterest);
        weth.mint(owner, wethInterest);
        matic.mint(owner, maticInterest);
        
        _simulateInterest(address(usdc), usdcInterest);
        _simulateInterest(address(weth), wethInterest);
        _simulateInterest(address(matic), maticInterest);
        
        console.log("Interest accrued for all assets");
        _logProtocolState();
        
        // 3. Users redeem and should get more than they deposited
        uint256 user1InitialUsdc = usdc.balanceOf(user1);
        uint256 user2InitialWeth = weth.balanceOf(user2);
        uint256 user3InitialMatic = matic.balanceOf(user3);
        
        _redeem(user1, address(usdc), saUSDC.balanceOf(user1));
        _redeem(user2, address(weth), saETH.balanceOf(user2));
        _redeem(user3, address(matic), saMATIC.balanceOf(user3));
        
        // 4. Verify users received their deposits plus interest
        uint256 user1FinalUsdc = usdc.balanceOf(user1);
        uint256 user2FinalWeth = weth.balanceOf(user2);
        uint256 user3FinalMatic = matic.balanceOf(user3);
        
        assertEq(user1FinalUsdc - user1InitialUsdc, usdcDeposit + usdcInterest, "User1 should receive deposit + interest");
        assertEq(user2FinalWeth - user2InitialWeth, wethDeposit + wethInterest, "User2 should receive deposit + interest");
        assertEq(user3FinalMatic - user3InitialMatic, maticDeposit + maticInterest, "User3 should receive deposit + interest");
        
        console.log("Full protocol flow test completed successfully");
    }

    function test_ConcurrentOperations() public {
        // Test multiple operations happening in sequence
        uint256 baseAmount = 1000e6;
        
        // User1 deposits
        _deposit(user1, address(usdc), baseAmount);
        
        // User2 deposits different amount
        _deposit(user2, address(usdc), baseAmount * 2);
        
        // Add some interest
        usdc.mint(owner, 150e6);
        _simulateInterest(address(usdc), 150e6);
        
        // User3 deposits after interest (should get fewer shares)
        _deposit(user3, address(usdc), baseAmount);
        
        // User1 redeems half
        _redeem(user1, address(usdc), saUSDC.balanceOf(user1) / 2);
        
        // Add more interest
        usdc.mint(owner, 100e6);
        _simulateInterest(address(usdc), 100e6);
        
        // All users redeem remaining
        _redeem(user1, address(usdc), saUSDC.balanceOf(user1));
        _redeem(user2, address(usdc), saUSDC.balanceOf(user2));
        _redeem(user3, address(usdc), saUSDC.balanceOf(user3));
        
        // Protocol should have minimal remaining assets (due to rounding)
        assertLe(saUSDC.totalAssets(), 10, "Should have minimal remaining assets");    }
}
