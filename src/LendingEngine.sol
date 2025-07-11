// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ILendingEngine } from "./interfaces/ILendingEngine.sol";
import { IStakeAaveToken } from "./interfaces/IStakeAaveToken.sol";

/**
 * @title LendingEngine
 * @author Alex Necsoiu
 * @notice Central coordinator for the lending protocol operations
 * @dev Manages deposits, redemptions, and interest accrual for supported assets
 * 
 * This contract follows the architecture patterns from the defi-stablecoin project:
 * - Modular design with clear separation of concerns
 * - Custom errors for gas efficiency and clear messaging
 * - Comprehensive events for off-chain tracking
 * - Proper access control and validation modifiers
 * - CEI (Checks-Effects-Interactions) pattern for security
 */
contract LendingEngine is ILendingEngine, ReentrancyGuard, Pausable, Ownable2Step {
    using SafeERC20 for IERC20;

    // --- Constants ---
    uint256 private constant PRECISION = 1e18;
    uint256 private constant MAX_ASSETS = 50; // Prevent unbounded array

    // --- State Variables ---
    mapping(address => AssetInfo) private s_supportedAssets;
    address[] private s_assetsList;

    // --- Events (additional to interface) ---
    event AssetDeactivated(address indexed underlying);
    event EmergencyPause();
    event EmergencyUnpause();

    // --- Errors ---
    error LendingEngine__NeedsMoreThanZero();
    error LendingEngine__AssetNotSupported(address asset);
    error LendingEngine__AssetAlreadyExists(address asset);
    error LendingEngine__InvalidTokenAddress();
    error LendingEngine__DepositFailed();
    error LendingEngine__RedeemFailed();
    error LendingEngine__InsufficientBalance();
    error LendingEngine__TooManyAssets();

    // --- Modifiers ---
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert LendingEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier supportedAsset(address underlying) {
        if (!s_supportedAssets[underlying].isActive) {
            revert LendingEngine__AssetNotSupported(underlying);
        }
        _;
    }

    // --- Constructor ---
    /**
     * @notice Initialize the lending engine
     * @param owner Address of the contract owner
     */
    constructor(address owner) Ownable(owner) {
        // Constructor logic minimal - assets added via addAsset function
    }

    // --- External Functions ---

    /**
     * @notice Add a new supported asset to the protocol
     * @param underlying Address of the underlying asset
     * @param protocolToken Address of the protocol token (saUSDC, saETH, etc.)
     */
    function addAsset(address underlying, address protocolToken) external onlyOwner {
        if (underlying == address(0) || protocolToken == address(0)) {
            revert LendingEngine__InvalidTokenAddress();
        }
        if (s_supportedAssets[underlying].isActive) {
            revert LendingEngine__AssetAlreadyExists(underlying);
        }
        if (s_assetsList.length >= MAX_ASSETS) {
            revert LendingEngine__TooManyAssets();
        }

        // Verify the protocol token is properly configured
        IStakeAaveToken token = IStakeAaveToken(protocolToken);
        if (token.asset() != underlying) {
            revert LendingEngine__InvalidTokenAddress();
        }

        // Add asset to mapping and list
        s_supportedAssets[underlying] = AssetInfo({
            token: token,
            underlying: underlying,
            isActive: true
        });
        s_assetsList.push(underlying);

        emit AssetAdded(underlying, protocolToken);
    }

    /**
     * @notice Deactivate an asset (emergency function)
     * @param underlying Address of the underlying asset
     */
    function deactivateAsset(address underlying) external onlyOwner supportedAsset(underlying) {
        s_supportedAssets[underlying].isActive = false;
        emit AssetDeactivated(underlying);
    }

    /**
     * @notice Deposit underlying assets and receive protocol tokens
     * @param underlying Address of the underlying asset
     * @param amount Amount of assets to deposit
     * @return sharesReceived Amount of protocol shares received
     */
    function deposit(address underlying, uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused
        supportedAsset(underlying) 
        moreThanZero(amount) 
        returns (uint256 sharesReceived) 
    {
        AssetInfo memory assetInfo = s_supportedAssets[underlying];
        IERC20 underlyingToken = IERC20(underlying);
        
        // Check user has sufficient balance
        if (underlyingToken.balanceOf(msg.sender) < amount) {
            revert LendingEngine__InsufficientBalance();
        }

        // Interactions: Transfer assets to this contract first
        underlyingToken.safeTransferFrom(msg.sender, address(this), amount);
        
        // Approve the protocol token to spend the assets using SafeERC20
        underlyingToken.safeIncreaseAllowance(address(assetInfo.token), amount);
        
        // Deposit into the protocol token
        sharesReceived = assetInfo.token.deposit(amount, msg.sender);

        emit Deposit(msg.sender, underlying, amount, sharesReceived);
    }

    /**
     * @notice Redeem protocol tokens for underlying assets
     * @param underlying Address of the underlying asset
     * @param shares Amount of shares to redeem
     * @return assetsReceived Amount of underlying assets received
     */
    function redeem(address underlying, uint256 shares) 
        external 
        nonReentrant 
        whenNotPaused
        supportedAsset(underlying) 
        moreThanZero(shares) 
        returns (uint256 assetsReceived) 
    {
        AssetInfo memory assetInfo = s_supportedAssets[underlying];
        
        // Check user has sufficient shares
        if (assetInfo.token.balanceOf(msg.sender) < shares) {
            revert LendingEngine__InsufficientBalance();
        }

        // Redeem shares for assets
        assetsReceived = assetInfo.token.redeem(shares, msg.sender, msg.sender);

        emit Redeem(msg.sender, underlying, shares, assetsReceived);
    }

    /**
     * @notice Simulate interest accrual for testing (adds yield to pools)
     * @param underlying Address of the underlying asset
     * @param interestAmount Amount of interest to add
     */
    function simulateInterest(address underlying, uint256 interestAmount) 
        external 
        onlyOwner 
        supportedAsset(underlying) 
        moreThanZero(interestAmount) 
    {
        AssetInfo memory assetInfo = s_supportedAssets[underlying];
        IERC20 underlyingToken = IERC20(underlying);
        
        // Transfer interest from owner to this contract
        underlyingToken.safeTransferFrom(msg.sender, address(this), interestAmount);
        
        // Approve the protocol token to spend the interest
        underlyingToken.safeIncreaseAllowance(address(assetInfo.token), interestAmount);
        
        // Accrue interest to the protocol token
        assetInfo.token.accrueInterest(interestAmount);

        emit InterestAccrued(underlying, interestAmount);
    }

    /**
     * @notice Emergency pause all operations
     */
    function emergencyPause() external onlyOwner {
        _pause();
        
        // Cache array length to save gas
        uint256 assetsLength = s_assetsList.length;
        
        // Pause all protocol tokens
        for (uint256 i = 0; i < assetsLength; ) {
            address underlying = s_assetsList[i];
            if (s_supportedAssets[underlying].isActive) {
                s_supportedAssets[underlying].token.pause();
            }
            unchecked {
                ++i;
            }
        }
        
        emit EmergencyPause();
    }

    /**
     * @notice Unpause all operations
     */
    function emergencyUnpause() external onlyOwner {
        // Cache array length to save gas
        uint256 assetsLength = s_assetsList.length;
        
        // Unpause all protocol tokens
        for (uint256 i = 0; i < assetsLength; ) {
            address underlying = s_assetsList[i];
            if (s_supportedAssets[underlying].isActive) {
                s_supportedAssets[underlying].token.unpause();
            }
            unchecked {
                ++i;
            }
        }

        _unpause();
        
        emit EmergencyUnpause();
    }

    // --- Public View Functions ---

    /**
     * @notice Get asset information
     * @param underlying Address of the underlying asset
     * @return info Asset information struct
     */
    function getAssetInfo(address underlying) public view supportedAsset(underlying) returns (AssetInfo memory info) {
        return s_supportedAssets[underlying];
    }

    /**
     * @notice Get all supported underlying assets
     * @return assets Array of underlying asset addresses
     */
    function getSupportedAssets() public view returns (address[] memory assets) {
        return s_assetsList;
    }

    /**
     * @notice Check if an asset is supported
     * @param underlying Address of the underlying asset
     * @return supported Whether the asset is supported
     */
    function isAssetSupported(address underlying) public view returns (bool supported) {
        return s_supportedAssets[underlying].isActive;
    }

    /**
     * @notice Get the total value locked for an asset
     * @param underlying Address of the underlying asset
     * @return totalAssets Total assets managed by the protocol token
     */
    function getTotalAssets(address underlying) external view supportedAsset(underlying) returns (uint256 totalAssets) {
        return s_supportedAssets[underlying].token.totalAssets();
    }

    /**
     * @notice Get the current share price for an asset (assets per share)
     * @param underlying Address of the underlying asset
     * @return sharePrice Current share price with 18 decimal precision
     * @dev Reverts if no shares exist (pool is empty)
     */
    function getSharePrice(address underlying) external view supportedAsset(underlying) returns (uint256 sharePrice) {
        IStakeAaveToken token = s_supportedAssets[underlying].token;
        uint256 totalShares = token.totalSupply();
        if (totalShares == 0) {
            revert LendingEngine__InsufficientBalance();
        }
        return (token.totalAssets() * PRECISION) / totalShares;
    }
}
