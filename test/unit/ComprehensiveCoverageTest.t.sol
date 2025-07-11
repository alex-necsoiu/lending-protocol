// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { LendingEngine } from "../../src/LendingEngine.sol";
import { StakeAaveUSDC } from "../../src/tokens/StakeAaveUSDC.sol";
import { BaseTest } from "./BaseTest.t.sol";

/**
 * @title ComprehensiveCoverageTest
 * @notice Tests to achieve 100% coverage for all contracts
 */
contract ComprehensiveCoverageTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    /// @dev Test LendingEngine owner-only functions and access control
    function test_OnlyOwnerFunctions() public {
        // Test deactivateAsset - UNCOVERED FUNCTION
        vm.prank(owner);
        lendingEngine.deactivateAsset(address(usdc));
        
        // Verify asset is deactivated
        assertFalse(lendingEngine.isAssetSupported(address(usdc)));
        
        // Test unauthorized access to addAsset (after deactivating)
        vm.expectRevert();
        vm.prank(user1);
        lendingEngine.addAsset(address(usdc), address(saUSDC));
        
        // Test unauthorized access to deactivateAsset
        vm.expectRevert();
        vm.prank(user1);
        lendingEngine.deactivateAsset(address(weth));
    }

    /// @dev Test LendingEngine getter functions - UNCOVERED FUNCTIONS
    function test_GetterFunctions() public view {
        // Test getSupportedAssets - UNCOVERED FUNCTION
        address[] memory supportedAssets = lendingEngine.getSupportedAssets();
        assertEq(supportedAssets.length, 3); // USDC, WETH, MATIC
        
        // Test getTotalAssets - UNCOVERED FUNCTION  
        uint256 totalAssets = lendingEngine.getTotalAssets(address(usdc));
        assertEq(totalAssets, saUSDC.totalAssets());
    }

    /// @dev Test MockERC20 functions - UNCOVERED FUNCTIONS
    function test_MockERC20Functions() public {
        // Get initial balance (BaseTest already gives user1 some USDC)
        uint256 initialBalance = usdc.balanceOf(user1);
        
        // Test mint function - UNCOVERED FUNCTION
        usdc.mint(user1, 1000e6);
        assertEq(usdc.balanceOf(user1), initialBalance + 1000e6);
        
        // Test burn function - UNCOVERED FUNCTION
        usdc.burn(user1, 500e6);
        assertEq(usdc.balanceOf(user1), initialBalance + 500e6);
    }

    /// @dev Test MockWETH functions - UNCOVERED FUNCTIONS
    function test_MockWETHFunctions() public {
        // Get initial balance (BaseTest already gives user1 some WETH)
        uint256 initialBalance = weth.balanceOf(user1);
        
        // Test deposit function - UNCOVERED FUNCTION
        uint256 depositAmount = 1 ether;
        
        // Give user1 some ETH
        vm.deal(user1, depositAmount);
        
        vm.prank(user1);
        weth.deposit{value: depositAmount}();
        
        // Check WETH balance increased
        assertEq(weth.balanceOf(user1), initialBalance + depositAmount);
        
        // Test withdraw function - UNCOVERED FUNCTION
        vm.prank(user1);
        weth.withdraw(depositAmount);
        
        // Check WETH balance decreased
        assertEq(weth.balanceOf(user1), initialBalance);
    }

    /// @dev Test StakeAaveToken edge cases - UNCOVERED BRANCHES
    function test_StakeAaveTokenEdgeCases() public {
        // Test getLendingEngine - UNCOVERED FUNCTION
        address lendingEngineAddr = saUSDC.getLendingEngine();
        assertEq(lendingEngineAddr, address(lendingEngine));
        
        // Test constructor with zero address - UNCOVERED BRANCH
        vm.expectRevert();
        new StakeAaveUSDC(address(0), address(lendingEngine));
        
        // Test setLendingEngine with zero address - UNCOVERED BRANCH
        vm.expectRevert();
        vm.prank(address(lendingEngine));
        saUSDC.setLendingEngine(address(0));
    }

    /// @dev Test LendingEngine error conditions - UNCOVERED BRANCHES
    function test_LendingEngineErrorConditions() public {
        // Test depositing to unsupported asset
        vm.prank(user1);
        vm.expectRevert();
        lendingEngine.deposit(address(this), 1000e18); // Random address
        
        // Test redeeming from unsupported asset  
        vm.prank(user1);
        vm.expectRevert();
        lendingEngine.redeem(address(this), 1000e18);
        
        // Test adding asset that already exists
        vm.prank(owner);
        vm.expectRevert();
        lendingEngine.addAsset(address(usdc), address(saUSDC)); // Already exists
        
        // Test deactivating asset that doesn't exist
        vm.prank(owner);
        vm.expectRevert();
        lendingEngine.deactivateAsset(address(this)); // Random address
    }

    /// @dev Test protocol state and logging functions - UNCOVERED FUNCTIONS
    function test_ProtocolStateLogging() public {
        // Test the protocol state logging functionality
        usdc.mint(user1, 1000e6);
        
        vm.startPrank(user1);
        usdc.approve(address(lendingEngine), 1000e6);
        lendingEngine.deposit(address(usdc), 1000e6);
        vm.stopPrank();
        
        // Test getTotalAssets after deposit
        uint256 totalAssets = lendingEngine.getTotalAssets(address(usdc));
        assertGt(totalAssets, 0);
        
        // Test getSupportedAssets returns correct number
        address[] memory supportedAssets = lendingEngine.getSupportedAssets();
        assertEq(supportedAssets.length, 3);
        
        // Verify the supported assets are correct
        bool foundUSDC = false;
        bool foundWETH = false;
        bool foundMATIC = false;
        
        for (uint256 i = 0; i < supportedAssets.length; i++) {
            if (supportedAssets[i] == address(usdc)) foundUSDC = true;
            if (supportedAssets[i] == address(weth)) foundWETH = true;
            if (supportedAssets[i] == address(matic)) foundMATIC = true;
        }
        
        assertTrue(foundUSDC);
        assertTrue(foundWETH);
        assertTrue(foundMATIC);
    }

    /// @dev Test edge cases for deposit and redeem with zero amounts
    function test_ZeroAmountOperations() public {
        // Test deposit with zero amount
        vm.prank(user1);
        vm.expectRevert();
        lendingEngine.deposit(address(usdc), 0);
        
        // Test redeem with zero amount
        vm.prank(user1);
        vm.expectRevert();
        lendingEngine.redeem(address(usdc), 0);
    }

    /// @dev Test remaining uncovered functions and branches
    function test_RemainingUncoveredCode() public {
        // Test MockERC20 decimals function - UNCOVERED FUNCTION
        assertEq(usdc.decimals(), 6);
        
        // Test MockWETH decimals function - UNCOVERED FUNCTION
        assertEq(weth.decimals(), 18);
        
        // Test MockWETH burn function - UNCOVERED FUNCTION
        uint256 initialBalance = weth.balanceOf(user1);
        weth.mint(user1, 1000e18);
        weth.burn(user1, 500e18);
        assertEq(weth.balanceOf(user1), initialBalance + 500e18);
        
        // Test MockWETH receive function - UNCOVERED FUNCTION
        uint256 sendAmount = 1 ether;
        vm.deal(user1, sendAmount);
        vm.prank(user1);
        (bool success, ) = address(weth).call{value: sendAmount}("");
        assertTrue(success);
        assertEq(weth.balanceOf(user1), initialBalance + 500e18 + sendAmount);
    }

    /// @dev Test StakeAaveToken zero address validation branches - UNCOVERED BRANCHES
    function test_StakeAaveTokenZeroAddressBranches() public {
        // Test setLendingEngine with zero address - UNCOVERED BRANCH
        vm.expectRevert();
        vm.prank(address(lendingEngine));
        saUSDC.setLendingEngine(address(0));
        
        // Test deposit with zero assets - UNCOVERED BRANCH
        vm.expectRevert();
        vm.prank(user1);
        saUSDC.deposit(0, user1);
        
        // Test redeem with zero shares - UNCOVERED BRANCH
        vm.expectRevert();
        vm.prank(user1);
        saUSDC.redeem(0, user1, user1);
        
        // Test deposit with zero amount - UNCOVERED BRANCH
        vm.expectRevert();
        vm.prank(user1);
        saUSDC.deposit(0, user1);
    }

    /// @dev Test LendingEngine additional functions - UNCOVERED FUNCTIONS
    function test_AdditionalLendingEngineFunctions() public {
        // Test getAssetInfo - UNCOVERED FUNCTION
        LendingEngine.AssetInfo memory info = lendingEngine.getAssetInfo(address(usdc));
        assertEq(info.underlying, address(usdc));
        assertEq(address(info.token), address(saUSDC));
        assertTrue(info.isActive);
        
        // Test getSharePrice - UNCOVERED FUNCTION
        uint256 sharePrice = lendingEngine.getSharePrice(address(usdc));
        assertGt(sharePrice, 0);
        
        // Test simulateInterest - UNCOVERED FUNCTION
        uint256 interestAmount = 1000e6;
        usdc.mint(owner, interestAmount);
        vm.startPrank(owner);
        usdc.approve(address(lendingEngine), interestAmount);
        lendingEngine.simulateInterest(address(usdc), interestAmount);
        vm.stopPrank();
    }

    /// @dev Test LendingEngine validation branches - UNCOVERED BRANCHES
    function test_LendingEngineValidationBranches() public {
        // Test addAsset with zero underlying address - UNCOVERED BRANCH
        vm.expectRevert();
        vm.prank(owner);
        lendingEngine.addAsset(address(0), address(saUSDC));
        
        // Test addAsset with zero protocol token address - UNCOVERED BRANCH
        vm.expectRevert();
        vm.prank(owner);
        lendingEngine.addAsset(address(usdc), address(0));
    }
}
