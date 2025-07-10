// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {BaseTest} from "../unit/BaseTest.t.sol";
import {LendingEngine} from "../../src/LendingEngine.sol";
import {StakeAaveToken} from "../../src/tokens/StakeAaveToken.sol";
import {StakeAaveUSDC} from "../../src/tokens/StakeAaveUSDC.sol";
import {StakeAaveETH} from "../../src/tokens/StakeAaveETH.sol";
import {StakeAaveMATIC} from "../../src/tokens/StakeAaveMATIC.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {MockWETH} from "../../src/mocks/MockWETH.sol";

/**
 * @title FullFlowTest
 * @author Pandora Labs
 * @notice Integration tests for end-to-end protocol flows
 * @dev Tests complete user journeys and cross-contract interactions
 */
contract FullFlowTest is BaseTest {
    /*//////////////////////////////////////////////////////////////
                            INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Test complete multi-asset deposit and redeem flow
     * @dev Tests deposits across all assets, interest accrual, and redemptions
     */
    function testFullMultiAssetFlow() public {
        // Initial deposits across all assets
        uint256 usdcAmount = 1000e6;
        uint256 ethAmount = 1 ether;
        uint256 maticAmount = 500e18;

        // User1 deposits USDC
        vm.startPrank(user1);
        usdc.approve(address(lendingEngine), usdcAmount);
        lendingEngine.deposit(address(usdc), usdcAmount);
        
        // User2 deposits ETH (via WETH wrapping)
        vm.startPrank(user2);
        vm.deal(user2, ethAmount);
        weth.deposit{value: ethAmount}();
        weth.approve(address(lendingEngine), ethAmount);
        lendingEngine.deposit(address(weth), ethAmount);
        
        // User3 deposits MATIC
        vm.startPrank(user3);
        matic.approve(address(lendingEngine), maticAmount);
        lendingEngine.deposit(address(matic), maticAmount);
        vm.stopPrank();

        // Verify initial balances
        assertEq(saUSDC.balanceOf(user1), usdcAmount);
        assertEq(saETH.balanceOf(user2), ethAmount);
        assertEq(saMATIC.balanceOf(user3), maticAmount);

        // Fast forward time and accrue interest
        vm.warp(block.timestamp + 365 days);
        
        // Simulate interest accrual - first mint interest tokens to owner
        vm.startPrank(owner);
        uint256 usdcInterest = (usdcAmount * 5) / 100; // 5% interest
        uint256 ethInterest = (ethAmount * 5) / 100;
        uint256 maticInterest = (maticAmount * 5) / 100;
        
        usdc.mint(owner, usdcInterest);
        usdc.approve(address(lendingEngine), usdcInterest);
        lendingEngine.simulateInterest(address(usdc), usdcInterest);
        
        weth.mint(owner, ethInterest);
        weth.approve(address(lendingEngine), ethInterest);
        lendingEngine.simulateInterest(address(weth), ethInterest);
        
        matic.mint(owner, maticInterest);
        matic.approve(address(lendingEngine), maticInterest);
        lendingEngine.simulateInterest(address(matic), maticInterest);
        vm.stopPrank();

        // Check balances have increased due to rebasing
        // Convert shares to assets to see the rebasing effect
        uint256 user1AssetValue = saUSDC.convertToAssets(saUSDC.balanceOf(user1));
        uint256 user2AssetValue = saETH.convertToAssets(saETH.balanceOf(user2));
        uint256 user3AssetValue = saMATIC.convertToAssets(saMATIC.balanceOf(user3));
        
        assertGt(user1AssetValue, usdcAmount);
        assertGt(user2AssetValue, ethAmount);
        assertGt(user3AssetValue, maticAmount);

        // Partial redemptions (redeem half of the shares)
        vm.startPrank(user1);
        uint256 user1Shares = saUSDC.balanceOf(user1);
        saUSDC.approve(address(lendingEngine), user1Shares / 2);
        lendingEngine.redeem(address(usdc), user1Shares / 2);
        
        vm.startPrank(user2);
        uint256 user2Shares = saETH.balanceOf(user2);
        saETH.approve(address(lendingEngine), user2Shares / 2);
        lendingEngine.redeem(address(weth), user2Shares / 2);
        
        vm.startPrank(user3);
        uint256 user3Shares = saMATIC.balanceOf(user3);
        saMATIC.approve(address(lendingEngine), user3Shares / 2);
        lendingEngine.redeem(address(matic), user3Shares / 2);
        vm.stopPrank();

        // Verify partial redemptions (shares should be halved)
        assertEq(saUSDC.balanceOf(user1), user1Shares / 2);
        assertEq(saETH.balanceOf(user2), user2Shares / 2);
        assertEq(saMATIC.balanceOf(user3), user3Shares / 2);

        // Complete redemptions
        vm.startPrank(user1);
        uint256 remainingUser1Shares = saUSDC.balanceOf(user1);
        saUSDC.approve(address(lendingEngine), remainingUser1Shares);
        lendingEngine.redeem(address(usdc), remainingUser1Shares);
        
        vm.startPrank(user2);
        uint256 remainingUser2Shares = saETH.balanceOf(user2);
        saETH.approve(address(lendingEngine), remainingUser2Shares);
        lendingEngine.redeem(address(weth), remainingUser2Shares);
        
        vm.startPrank(user3);
        uint256 remainingUser3Shares = saMATIC.balanceOf(user3);
        saMATIC.approve(address(lendingEngine), remainingUser3Shares);
        lendingEngine.redeem(address(matic), remainingUser3Shares);
        vm.stopPrank();

        // Verify complete redemptions
        assertEq(saUSDC.balanceOf(user1), 0);
        assertEq(saETH.balanceOf(user2), 0);
        assertEq(saMATIC.balanceOf(user3), 0);
    }

    /**
     * @notice Test cross-user transfer and redemption scenarios
     * @dev Tests token transfers between users and subsequent redemptions
     */
    function testCrossUserTransferFlow() public {
        uint256 depositAmount = 1000e6;

        // User1 deposits USDC
        vm.startPrank(user1);
        usdc.approve(address(lendingEngine), depositAmount);
        lendingEngine.deposit(address(usdc), depositAmount);

        // Transfer half to user2
        uint256 transferAmount = depositAmount / 2;
        saUSDC.transfer(user2, transferAmount);
        vm.stopPrank();

        // Verify balances
        assertEq(saUSDC.balanceOf(user1), transferAmount);
        assertEq(saUSDC.balanceOf(user2), transferAmount);

        // Accrue interest
        vm.warp(block.timestamp + 30 days);
        
        vm.startPrank(owner);
        uint256 interestAmount = (transferAmount * 2 * 1) / 100; // 1% interest on total deposits
        usdc.mint(owner, interestAmount);
        usdc.approve(address(lendingEngine), interestAmount);
        lendingEngine.simulateInterest(address(usdc), interestAmount);
        vm.stopPrank();

        // Both users should have increased balances due to rebasing
        uint256 user1AssetValue = saUSDC.convertToAssets(saUSDC.balanceOf(user1));
        uint256 user2AssetValue = saUSDC.convertToAssets(saUSDC.balanceOf(user2));
        
        assertGt(user1AssetValue, transferAmount);
        assertGt(user2AssetValue, transferAmount);
        assertEq(user1AssetValue, user2AssetValue); // Should be equal since they hold same amount

        // Both users redeem their tokens
        vm.startPrank(user1);
        uint256 user1Shares = saUSDC.balanceOf(user1);
        saUSDC.approve(address(lendingEngine), user1Shares);
        lendingEngine.redeem(address(usdc), user1Shares);
        
        vm.startPrank(user2);
        uint256 user2Shares = saUSDC.balanceOf(user2);
        saUSDC.approve(address(lendingEngine), user2Shares);
        lendingEngine.redeem(address(usdc), user2Shares);
        vm.stopPrank();

        // Verify redemptions
        assertEq(saUSDC.balanceOf(user1), 0);
        assertEq(saUSDC.balanceOf(user2), 0);
        
        // Users should have received underlying assets
        assertGt(usdc.balanceOf(user1), 0);
        assertGt(usdc.balanceOf(user2), 0);
    }

    /**
     * @notice Test protocol behavior under stress conditions
     * @dev Tests multiple users, rapid deposits/redemptions, and edge cases
     */
    function testStressTestFlow() public {
        address[] memory users = new address[](5);
        users[0] = user1;
        users[1] = user2;
        users[2] = user3;
        users[3] = makeAddr("user4");
        users[4] = makeAddr("user5");

        uint256 baseAmount = 100e6;

        // Multiple users deposit varying amounts
        for (uint256 i = 0; i < users.length; i++) {
            uint256 amount = baseAmount * (i + 1);
            usdc.mint(users[i], amount);
            
            vm.startPrank(users[i]);
            usdc.approve(address(lendingEngine), amount);
            lendingEngine.deposit(address(usdc), amount);
            vm.stopPrank();
        }

        // Verify total supply matches deposits
        uint256 expectedTotalSupply = baseAmount + (baseAmount * 2) + (baseAmount * 3) + (baseAmount * 4) + (baseAmount * 5);
        assertEq(saUSDC.totalSupply(), expectedTotalSupply);

        // Multiple interest accruals over time
        vm.startPrank(owner);
        for (uint256 i = 0; i < 10; i++) {
            vm.warp(block.timestamp + 7 days);
            uint256 weeklyInterest = expectedTotalSupply / 1000; // 0.1% weekly
            usdc.mint(owner, weeklyInterest);
            usdc.approve(address(lendingEngine), weeklyInterest);
            lendingEngine.simulateInterest(address(usdc), weeklyInterest);
        }
        vm.stopPrank();

        // All users should have increased balances (convert to assets to see rebasing)
        for (uint256 i = 0; i < users.length; i++) {
            uint256 expectedMinBalance = baseAmount * (i + 1);
            uint256 actualAssetValue = saUSDC.convertToAssets(saUSDC.balanceOf(users[i]));
            assertGt(actualAssetValue, expectedMinBalance);
        }

        // Rapid partial redemptions
        for (uint256 i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            uint256 balance = saUSDC.balanceOf(users[i]);
            saUSDC.approve(address(lendingEngine), balance / 4);
            lendingEngine.redeem(address(usdc), balance / 4);
            vm.stopPrank();
        }

        // Final complete redemptions
        for (uint256 i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            uint256 balance = saUSDC.balanceOf(users[i]);
            saUSDC.approve(address(lendingEngine), balance);
            lendingEngine.redeem(address(usdc), balance);
            vm.stopPrank();
        }

        // Verify all tokens redeemed
        assertEq(saUSDC.totalSupply(), 0);
    }

    /**
     * @notice Test protocol upgrade simulation
     * @dev Tests adding new assets and protocol modifications
     */
    function testProtocolUpgradeFlow() public {
        // Deploy new mock token
        MockERC20 newToken = new MockERC20("New Token", "NEW", 18);
        
        // Create a concrete implementation similar to StakeAaveUSDC
        StakeAaveToken saNewToken = new StakeAaveUSDC(address(newToken), owner);

        // Register new asset (only owner can do this)
        vm.startPrank(owner);
        saNewToken.setLendingEngine(address(lendingEngine));
        lendingEngine.addAsset(address(newToken), address(saNewToken));
        vm.stopPrank();

        // Test deposit with new asset
        uint256 amount = 1000e18;
        newToken.mint(user1, amount);
        
        vm.startPrank(user1);
        newToken.approve(address(lendingEngine), amount);
        lendingEngine.deposit(address(newToken), amount);
        vm.stopPrank();

        // Verify deposit worked
        assertEq(saNewToken.balanceOf(user1), amount);
        
        // Test interest accrual on new asset
        vm.warp(block.timestamp + 365 days);
        
        vm.startPrank(owner);
        uint256 interestAmount = (amount * 5) / 100; // 5% interest
        newToken.mint(owner, interestAmount);
        newToken.approve(address(lendingEngine), interestAmount);
        lendingEngine.simulateInterest(address(newToken), interestAmount);
        vm.stopPrank();
        
        assertGt(saNewToken.convertToAssets(saNewToken.balanceOf(user1)), amount);
        
        // Test redemption
        vm.startPrank(user1);
        uint256 sharesToRedeem = saNewToken.balanceOf(user1);
        saNewToken.approve(address(lendingEngine), sharesToRedeem);
        lendingEngine.redeem(address(newToken), sharesToRedeem);
        vm.stopPrank();
        
        assertEq(saNewToken.balanceOf(user1), 0);
        assertGt(newToken.balanceOf(user1), 0);
    }

    /**
     * @notice Test mixed ETH and ERC20 operations
     * @dev Tests combinations of ETH and token deposits/redemptions
     */
    function testMixedAssetFlow() public {
        uint256 usdcAmount = 1000e6;
        uint256 ethAmount = 2 ether;

        // User deposits both USDC and ETH
        vm.startPrank(user1);
        vm.deal(user1, ethAmount);
        
        // Deposit USDC
        usdc.approve(address(lendingEngine), usdcAmount);
        lendingEngine.deposit(address(usdc), usdcAmount);
        
        // Deposit ETH (via WETH wrapping)
        weth.deposit{value: ethAmount}();
        weth.approve(address(lendingEngine), ethAmount);
        lendingEngine.deposit(address(weth), ethAmount);
        vm.stopPrank();

        // Verify balances
        assertEq(saUSDC.balanceOf(user1), usdcAmount);
        assertEq(saETH.balanceOf(user1), ethAmount);

        // Accrue interest on both assets
        vm.warp(block.timestamp + 180 days);
        
        vm.startPrank(owner);
        uint256 usdcInterest = (usdcAmount * 3) / 100; // 3% interest for 6 months
        uint256 ethInterest = (ethAmount * 3) / 100;
        
        usdc.mint(owner, usdcInterest);
        usdc.approve(address(lendingEngine), usdcInterest);
        lendingEngine.simulateInterest(address(usdc), usdcInterest);
        
        weth.mint(owner, ethInterest);
        weth.approve(address(lendingEngine), ethInterest);
        lendingEngine.simulateInterest(address(weth), ethInterest);
        vm.stopPrank();

        uint256 usdcBalance = saUSDC.convertToAssets(saUSDC.balanceOf(user1));
        uint256 ethBalance = saETH.convertToAssets(saETH.balanceOf(user1));

        assertGt(usdcBalance, usdcAmount);
        assertGt(ethBalance, ethAmount);

        // Transfer tokens to another user (transfer shares, not assets)
        vm.startPrank(user1);
        uint256 usdcSharesToTransfer = saUSDC.balanceOf(user1) / 2;
        uint256 ethSharesToTransfer = saETH.balanceOf(user1) / 2;
        
        saUSDC.transfer(user2, usdcSharesToTransfer);
        saETH.transfer(user2, ethSharesToTransfer);
        vm.stopPrank();

        // Both users redeem their holdings
        vm.startPrank(user1);
        uint256 user1USDCShares = saUSDC.balanceOf(user1);
        uint256 user1ETHShares = saETH.balanceOf(user1);
        saUSDC.approve(address(lendingEngine), user1USDCShares);
        saETH.approve(address(lendingEngine), user1ETHShares);
        lendingEngine.redeem(address(usdc), user1USDCShares);
        lendingEngine.redeem(address(weth), user1ETHShares);
        
        vm.startPrank(user2);
        uint256 user2USDCShares = saUSDC.balanceOf(user2);
        uint256 user2ETHShares = saETH.balanceOf(user2);
        saUSDC.approve(address(lendingEngine), user2USDCShares);
        saETH.approve(address(lendingEngine), user2ETHShares);
        lendingEngine.redeem(address(usdc), user2USDCShares);
        lendingEngine.redeem(address(weth), user2ETHShares);
        vm.stopPrank();

        // Verify all tokens redeemed
        assertEq(saUSDC.balanceOf(user1), 0);
        assertEq(saUSDC.balanceOf(user2), 0);
        assertEq(saETH.balanceOf(user1), 0);
        assertEq(saETH.balanceOf(user2), 0);
    }

    /**
     * @notice Test gas efficiency across operations
     * @dev Tests gas consumption for various operations
     */
    function testGasEfficiencyFlow() public {
        uint256 amount = 1000e6;

        // Measure gas for deposit
        uint256 gasBefore = gasleft();
        vm.startPrank(user1);
        usdc.approve(address(lendingEngine), amount);
        lendingEngine.deposit(address(usdc), amount);
        vm.stopPrank();
        uint256 depositGas = gasBefore - gasleft();

        // Measure gas for interest accrual
        gasBefore = gasleft();
        vm.warp(block.timestamp + 365 days);
        
        vm.startPrank(owner);
        uint256 interestAmount = (amount * 5) / 100; // 5% interest
        usdc.mint(owner, interestAmount);
        usdc.approve(address(lendingEngine), interestAmount);
        lendingEngine.simulateInterest(address(usdc), interestAmount);
        vm.stopPrank();
        
        uint256 interestGas = gasBefore - gasleft();

        // Measure gas for redemption
        gasBefore = gasleft();
        vm.startPrank(user1);
        uint256 sharesToRedeem = saUSDC.balanceOf(user1);
        saUSDC.approve(address(lendingEngine), sharesToRedeem);
        lendingEngine.redeem(address(usdc), sharesToRedeem);
        vm.stopPrank();
        uint256 redeemGas = gasBefore - gasleft();

        // Log gas usage for analysis
        emit log_named_uint("Deposit gas", depositGas);
        emit log_named_uint("Interest accrual gas", interestGas);
        emit log_named_uint("Redeem gas", redeemGas);

        // Basic gas efficiency checks (adjust thresholds as needed)
        assertLt(depositGas, 250000, "Deposit gas too high");
        assertLt(interestGas, 150000, "Interest accrual gas too high");
        assertLt(redeemGas, 200000, "Redeem gas too high");
    }
}
