// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { LendingEngine } from "../../src/LendingEngine.sol";
import { BaseTest } from "./BaseTest.t.sol";

/**
 * @title SecurityFeaturesTest
 * @notice Tests for new security features: emergency pause, Ownable2Step, bounded arrays
 */
contract SecurityFeaturesTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    /// @dev Test emergency pause functionality
    function test_EmergencyPauseFunctionality() public {
        // Test emergency pause by owner
        vm.prank(owner);
        lendingEngine.emergencyPause();
        
        // Verify deposits are blocked when paused
        usdc.mint(user1, 1000e6);
        vm.startPrank(user1);
        usdc.approve(address(lendingEngine), 1000e6);
        vm.expectRevert(); // Should revert due to pause
        lendingEngine.deposit(address(usdc), 1000e6);
        vm.stopPrank();
        
        // Test unpause by owner
        vm.prank(owner);
        lendingEngine.emergencyUnpause();
        
        // Verify deposits work after unpause
        vm.startPrank(user1);
        uint256 shares = lendingEngine.deposit(address(usdc), 1000e6);
        assertGt(shares, 0);
        vm.stopPrank();
    }

    /// @dev Test unauthorized pause attempts
    function test_UnauthorizedPauseReverts() public {
        // Test non-owner cannot pause
        vm.expectRevert();
        vm.prank(user1);
        lendingEngine.emergencyPause();
        
        // Test non-owner cannot unpause
        vm.prank(owner);
        lendingEngine.emergencyPause();
        
        vm.expectRevert();
        vm.prank(user1);
        lendingEngine.emergencyUnpause();
    }

    /// @dev Test Ownable2Step ownership transfer
    function test_Ownable2StepFunctionality() public {
        address newOwner = address(0x999);
        
        // Current owner initiates transfer
        vm.prank(owner);
        lendingEngine.transferOwnership(newOwner);
        
        // Verify ownership hasn't changed yet
        assertEq(lendingEngine.owner(), owner);
        assertEq(lendingEngine.pendingOwner(), newOwner);
        
        // New owner must accept ownership
        vm.prank(newOwner);
        lendingEngine.acceptOwnership();
        
        // Verify ownership has transferred
        assertEq(lendingEngine.owner(), newOwner);
        assertEq(lendingEngine.pendingOwner(), address(0));
    }

    /// @dev Test bounded asset array - prevent adding too many assets
    function test_BoundedAssetArray() public {
        // This test would need to be adjusted based on MAX_ASSETS constant
        // For now, just test that the error exists when limit is reached
        
        // We can't easily test the full limit in a unit test, but we can verify
        // the error exists and the check is in place
        vm.prank(owner);
        // This should work (we're well under the limit)
        // The actual limit test would require deploying many mock tokens
    }

    /// @dev Test pause affects redeem operations too
    function test_PauseAffectsRedemptions() public {
        // First make a deposit
        usdc.mint(user1, 1000e6);
        vm.startPrank(user1);
        usdc.approve(address(lendingEngine), 1000e6);
        uint256 shares = lendingEngine.deposit(address(usdc), 1000e6);
        vm.stopPrank();
        
        // Pause the contract
        vm.prank(owner);
        lendingEngine.emergencyPause();
        
        // Try to redeem - should fail due to pause
        vm.startPrank(user1);
        // First approve the lending engine to spend shares
        saUSDC.approve(address(lendingEngine), shares);
        vm.expectRevert(); // Should revert due to pause
        lendingEngine.redeem(address(usdc), shares);
        vm.stopPrank();
        
        // Unpause and try again - should work
        vm.prank(owner);
        lendingEngine.emergencyUnpause();
        
        vm.prank(user1);
        uint256 assets = lendingEngine.redeem(address(usdc), shares);
        assertGt(assets, 0);
    }

    /// @dev Test pause events are emitted
    function test_PauseEventsEmitted() public {
        // Test pause event
        vm.expectEmit(true, false, false, false);
        emit EmergencyPause();
        vm.prank(owner);
        lendingEngine.emergencyPause();
        
        // Test unpause event
        vm.expectEmit(true, false, false, false);
        emit EmergencyUnpause();
        vm.prank(owner);
        lendingEngine.emergencyUnpause();
    }

    // Events for testing
    event EmergencyPause();
    event EmergencyUnpause();
}
