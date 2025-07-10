// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IStakeAaveToken
 * @notice Interface for rebasing StakeAave tokens that earn yield
 * @dev Extends IERC20 with rebasing functionality
 */
interface IStakeAaveToken is IERC20 {
    // --- Events ---
    
    /**
     * @notice Emitted when tokens are deposited and shares minted
     * @param user Address of the depositor
     * @param assets Amount of underlying assets deposited
     * @param shares Amount of protocol shares minted
     */
    event Deposit(address indexed user, uint256 assets, uint256 shares);
    
    /**
     * @notice Emitted when tokens are redeemed and shares burned
     * @param user Address of the redeemer
     * @param assets Amount of underlying assets withdrawn
     * @param shares Amount of protocol shares burned
     */
    event Redeem(address indexed user, uint256 assets, uint256 shares);
    
    /**
     * @notice Emitted when interest is accrued to the pool
     * @param totalAssets New total assets after interest accrual
     * @param interestEarned Amount of interest earned
     */
    event InterestAccrued(uint256 totalAssets, uint256 interestEarned);

    // --- External Functions ---
    
    /**
     * @notice Get the underlying asset address
     * @return Address of the underlying ERC20 token
     */
    function asset() external view returns (address);
    
    /**
     * @notice Get total assets under management
     * @return Total amount of underlying assets
     */
    function totalAssets() external view returns (uint256);
    
    /**
     * @notice Convert assets to shares
     * @param assets Amount of assets to convert
     * @return shares Equivalent amount of shares
     */
    function convertToShares(uint256 assets) external view returns (uint256 shares);
    
    /**
     * @notice Convert shares to assets
     * @param shares Amount of shares to convert
     * @return assets Equivalent amount of assets
     */
    function convertToAssets(uint256 shares) external view returns (uint256 assets);
    
    /**
     * @notice Deposit assets and receive shares
     * @param assets Amount of assets to deposit
     * @param receiver Address to receive the shares
     * @return shares Amount of shares minted
     */
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    
    /**
     * @notice Redeem shares for assets
     * @param shares Amount of shares to redeem
     * @param receiver Address to receive the assets
     * @param owner Address that owns the shares
     * @return assets Amount of assets withdrawn
     */
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
    
    /**
     * @notice Accrue interest to the pool (only callable by LendingEngine)
     * @param interestAmount Amount of interest to add
     */
    function accrueInterest(uint256 interestAmount) external;
}
