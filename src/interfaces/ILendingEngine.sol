// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IStakeAaveToken } from "./IStakeAaveToken.sol";

/**
 * @title ILendingEngine
 * @notice Interface for the main lending protocol engine
 * @dev Central coordinator for all lending operations
 */
interface ILendingEngine {
    // --- Type Declarations ---
    
    /**
     * @notice Supported asset information
     * @param token Protocol token (saUSDC, saETH, saMATIC)
     * @param underlying Underlying asset (USDC, WETH, MATIC)
     * @param isActive Whether the asset is currently supported
     */
    struct AssetInfo {
        IStakeAaveToken token;
        address underlying;
        bool isActive;
    }

    // --- Events ---
    
    /**
     * @notice Emitted when a user deposits assets
     * @param user Address of the depositor
     * @param underlying Address of the underlying asset
     * @param amount Amount of assets deposited
     * @param sharesReceived Amount of protocol shares received
     */
    event Deposit(address indexed user, address indexed underlying, uint256 amount, uint256 sharesReceived);
    
    /**
     * @notice Emitted when a user redeems shares
     * @param user Address of the redeemer
     * @param underlying Address of the underlying asset
     * @param sharesRedeemed Amount of shares redeemed
     * @param assetsReceived Amount of underlying assets received
     */
    event Redeem(address indexed user, address indexed underlying, uint256 sharesRedeemed, uint256 assetsReceived);
    
    /**
     * @notice Emitted when interest is accrued to a pool
     * @param underlying Address of the underlying asset
     * @param interestAmount Amount of interest accrued
     */
    event InterestAccrued(address indexed underlying, uint256 interestAmount);
    
    /**
     * @notice Emitted when a new asset is added to the protocol
     * @param underlying Address of the underlying asset
     * @param protocolToken Address of the protocol token
     */
    event AssetAdded(address indexed underlying, address indexed protocolToken);

    // --- External Functions ---
    
    /**
     * @notice Deposit underlying assets and receive protocol tokens
     * @param underlying Address of the underlying asset
     * @param amount Amount of assets to deposit
     * @return sharesReceived Amount of protocol shares received
     */
    function deposit(address underlying, uint256 amount) external returns (uint256 sharesReceived);
    
    /**
     * @notice Redeem protocol tokens for underlying assets
     * @param underlying Address of the underlying asset
     * @param shares Amount of shares to redeem
     * @return assetsReceived Amount of underlying assets received
     */
    function redeem(address underlying, uint256 shares) external returns (uint256 assetsReceived);
    
    /**
     * @notice Simulate interest accrual for testing (adds yield to pools)
     * @param underlying Address of the underlying asset
     * @param interestAmount Amount of interest to add
     */
    function simulateInterest(address underlying, uint256 interestAmount) external;
    
    /**
     * @notice Get asset information
     * @param underlying Address of the underlying asset
     * @return info Asset information struct
     */
    function getAssetInfo(address underlying) external view returns (AssetInfo memory info);
    
    /**
     * @notice Get all supported underlying assets
     * @return assets Array of underlying asset addresses
     */
    function getSupportedAssets() external view returns (address[] memory assets);
    
    /**
     * @notice Check if an asset is supported
     * @param underlying Address of the underlying asset
     * @return supported Whether the asset is supported
     */
    function isAssetSupported(address underlying) external view returns (bool supported);
}
