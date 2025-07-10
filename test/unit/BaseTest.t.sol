// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { LendingEngine } from "../../src/LendingEngine.sol";
import { StakeAaveUSDC } from "../../src/tokens/StakeAaveUSDC.sol";
import { StakeAaveETH } from "../../src/tokens/StakeAaveETH.sol";
import { StakeAaveMATIC } from "../../src/tokens/StakeAaveMATIC.sol";
import { MockERC20 } from "../../src/mocks/MockERC20.sol";
import { MockWETH } from "../../src/mocks/MockWETH.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title BaseTest
 * @author Alex Necsoiu
 * @notice Base test contract with common setup and utilities
 * @dev Provides shared functionality for all test contracts
 */
abstract contract BaseTest is Test {
    // --- Test Contracts ---
    LendingEngine public lendingEngine;
    StakeAaveUSDC public saUSDC;
    StakeAaveETH public saETH;
    StakeAaveMATIC public saMATIC;
    
    // --- Mock Tokens ---
    MockERC20 public usdc;
    MockWETH public weth;
    MockERC20 public matic;

    // --- Test Users ---
    address public owner;
    address public user1;
    address public user2;
    address public user3;

    // --- Constants ---
    uint256 public constant INITIAL_BALANCE = 1000000e18; // 1M tokens
    uint256 public constant USDC_INITIAL = 1000000e6; // 1M USDC (6 decimals)
    uint256 public constant PRECISION = 1e18;

    // --- Events for Testing ---
    event Deposit(address indexed user, address indexed underlying, uint256 amount, uint256 sharesReceived);
    event Redeem(address indexed user, address indexed underlying, uint256 sharesRedeemed, uint256 assetsReceived);
    event InterestAccrued(address indexed underlying, uint256 interestAmount);

    // --- Setup ---
    function setUp() public virtual {
        // Setup test users
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        // Deploy protocol directly (without script to avoid broadcast conflicts)
        vm.startPrank(owner);
        
        // Deploy mock tokens
        usdc = new MockERC20("USD Coin", "USDC", 6);
        weth = new MockWETH();
        matic = new MockERC20("Polygon", "MATIC", 18);
        
        // Deploy lending engine
        lendingEngine = new LendingEngine(owner);
        
        // Deploy protocol tokens (owner is the test owner, not lending engine)
        saUSDC = new StakeAaveUSDC(address(usdc), owner);
        saETH = new StakeAaveETH(address(weth), owner);
        saMATIC = new StakeAaveMATIC(address(matic), owner);
        
        // Set lending engine addresses for protocol tokens
        saUSDC.setLendingEngine(address(lendingEngine));
        saETH.setLendingEngine(address(lendingEngine));
        saMATIC.setLendingEngine(address(lendingEngine));
        
        // Register assets
        lendingEngine.addAsset(address(usdc), address(saUSDC));
        lendingEngine.addAsset(address(weth), address(saETH));
        lendingEngine.addAsset(address(matic), address(saMATIC));
        
        vm.stopPrank();

        // Setup initial token balances for users
        _setupUserBalances();
    }

    // --- Helper Functions ---

    /**
     * @notice Setup initial token balances for test users
     */
    function _setupUserBalances() internal {
        address[] memory users = new address[](3);
        users[0] = user1;
        users[1] = user2;
        users[2] = user3;

        for (uint256 i = 0; i < users.length; i++) {
            // Mint USDC (6 decimals)
            usdc.mint(users[i], USDC_INITIAL);
            
            // Mint WETH (18 decimals)
            weth.mint(users[i], INITIAL_BALANCE);
            
            // Mint MATIC (18 decimals)
            matic.mint(users[i], INITIAL_BALANCE);
            
            // Give users some ETH for gas
            vm.deal(users[i], 100 ether);
        }
    }

    /**
     * @notice Helper to deposit tokens for a user
     * @param user User address
     * @param token Token address
     * @param amount Amount to deposit
     */
    function _deposit(address user, address token, uint256 amount) internal {
        vm.startPrank(user);
        IERC20(token).approve(address(lendingEngine), amount);
        lendingEngine.deposit(token, amount);
        vm.stopPrank();
    }

    /**
     * @notice Helper to redeem shares for a user
     * @param user User address
     * @param token Token address
     * @param shares Amount of shares to redeem
     */
    function _redeem(address user, address token, uint256 shares) internal {
        vm.startPrank(user);
        // Approve the lending engine to spend shares
        if (token == address(usdc)) {
            saUSDC.approve(address(lendingEngine), shares);
        } else if (token == address(weth)) {
            saETH.approve(address(lendingEngine), shares);
        } else if (token == address(matic)) {
            saMATIC.approve(address(lendingEngine), shares);
        }
        lendingEngine.redeem(token, shares);
        vm.stopPrank();
    }

    /**
     * @notice Helper to simulate interest accrual
     * @param token Token address
     * @param interestAmount Amount of interest to add
     */
    function _simulateInterest(address token, uint256 interestAmount) internal {
        vm.startPrank(owner);
        IERC20(token).approve(address(lendingEngine), interestAmount);
        lendingEngine.simulateInterest(token, interestAmount);
        vm.stopPrank();
    }

    /**
     * @notice Get protocol token for underlying asset
     * @param underlying Underlying asset address
     * @return protocolToken Protocol token contract
     */
    function _getProtocolToken(address underlying) internal view returns (IERC20 protocolToken) {
        if (underlying == address(usdc)) return IERC20(address(saUSDC));
        if (underlying == address(weth)) return IERC20(address(saETH));
        if (underlying == address(matic)) return IERC20(address(saMATIC));
        revert("Unsupported token");
    }

    /**
     * @notice Assert approximate equality (within 0.01%)
     * @param actual Actual value
     * @param expected Expected value
     * @param message Error message
     */
    function assertApproxEqRel(uint256 actual, uint256 expected, string memory message) internal pure {
        uint256 tolerance = expected / 10000; // 0.01%
        if (actual > expected) {
            assertLe(actual - expected, tolerance, message);
        } else {
            assertLe(expected - actual, tolerance, message);
        }
    }

    /**
     * @notice Check if protocol token balance represents expected underlying assets
     * @param user User address
     * @param underlying Underlying token address
     * @param expectedAssets Expected underlying assets
     */
    function _assertUserAssetBalance(address user, address underlying, uint256 expectedAssets) internal view {
        IERC20 protocolToken = _getProtocolToken(underlying);
        uint256 userShares = protocolToken.balanceOf(user);
        
        if (underlying == address(usdc)) {
            uint256 actualAssets = saUSDC.convertToAssets(userShares);
            assertApproxEqRel(actualAssets, expectedAssets, "USDC balance mismatch");
        } else if (underlying == address(weth)) {
            uint256 actualAssets = saETH.convertToAssets(userShares);
            assertApproxEqRel(actualAssets, expectedAssets, "WETH balance mismatch");
        } else if (underlying == address(matic)) {
            uint256 actualAssets = saMATIC.convertToAssets(userShares);
            assertApproxEqRel(actualAssets, expectedAssets, "MATIC balance mismatch");
        }
    }

    /**
     * @notice Print protocol state for debugging
     */
    function _logProtocolState() internal view {
        console.log("\n=== PROTOCOL STATE ===");
        console.log("USDC Total Assets:", saUSDC.totalAssets());
        console.log("USDC Total Supply:", saUSDC.totalSupply());
        console.log("WETH Total Assets:", saETH.totalAssets());
        console.log("WETH Total Supply:", saETH.totalSupply());
        console.log("MATIC Total Assets:", saMATIC.totalAssets());
        console.log("MATIC Total Supply:", saMATIC.totalSupply());
        console.log("====================\n");
    }
}
