// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IStakeAaveToken } from "../interfaces/IStakeAaveToken.sol";

/**
 * @title StakeAaveToken
 * @author Alex Necsoiu
 * @notice Base implementation for rebasing StakeAave tokens (saUSDC, saETH, saMATIC)
 * @dev Implements a vault-like pattern with rebasing through share/asset conversion
 * 
 * This contract follows the architecture patterns from the defi-stablecoin project:
 * - Clear separation of concerns with modular design
 * - Custom errors for gas efficiency  
 * - Events for comprehensive off-chain tracking
 * - Modifiers for access control and validation
 * - Proper contract section ordering per style guide
 */
abstract contract StakeAaveToken is IStakeAaveToken, ERC20, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // --- Constants ---
    uint256 private constant PRECISION = 1e18;

    // --- State Variables ---
    IERC20 private immutable i_asset;
    uint256 private s_totalAssets;
    address private s_lendingEngine;

    // --- Events (additional to interface) ---
    event LendingEngineSet(address indexed lendingEngine);

    // --- Errors ---
    error StakeAaveToken__NeedsMoreThanZero();
    error StakeAaveToken__NotLendingEngine();
    error StakeAaveToken__InsufficientShares();
    error StakeAaveToken__InsufficientAssets();
    error StakeAaveToken__TransferFailed();

    // --- Modifiers ---
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) revert StakeAaveToken__NeedsMoreThanZero();
        _;
    }

    modifier onlyLendingEngine() {
        if (msg.sender != s_lendingEngine) revert StakeAaveToken__NotLendingEngine();
        _;
    }

    // --- Constructor ---
    /**
     * @notice Initialize the StakeAave token
     * @param underlyingAsset Address of the underlying asset
     * @param name Name of the token (e.g., "Stake Aave USDC")
     * @param symbol Symbol of the token (e.g., "saUSDC")
     * @param owner Address of the contract owner
     */
    constructor(
        address underlyingAsset,
        string memory name,
        string memory symbol,
        address owner
    ) ERC20(name, symbol) Ownable(owner) {
        if (underlyingAsset == address(0)) revert StakeAaveToken__NeedsMoreThanZero();
        i_asset = IERC20(underlyingAsset);
    }

    // --- External Functions ---

    /**
     * @notice Set the lending engine address (only owner)
     * @param lendingEngine Address of the lending engine
     */
    function setLendingEngine(address lendingEngine) external onlyOwner {
        if (lendingEngine == address(0)) revert StakeAaveToken__NeedsMoreThanZero();
        s_lendingEngine = lendingEngine;
        emit LendingEngineSet(lendingEngine);
    }

    /**
     * @notice Deposit assets and receive shares
     * @param assets Amount of assets to deposit
     * @param receiver Address to receive the shares
     * @return shares Amount of shares minted
     */
    function deposit(uint256 assets, address receiver) 
        external 
        nonReentrant 
        moreThanZero(assets) 
        returns (uint256 shares) 
    {
        // Calculate shares to mint (before updating total assets)
        shares = convertToShares(assets);
        if (shares == 0) revert StakeAaveToken__InsufficientShares();

        // Effects: Update state
        s_totalAssets += assets;
        _mint(receiver, shares);

        // Interactions: Transfer assets from user
        i_asset.safeTransferFrom(msg.sender, address(this), assets);

        emit Deposit(msg.sender, assets, shares);
    }

    /**
     * @notice Redeem shares for assets
     * @param shares Amount of shares to redeem
     * @param receiver Address to receive the assets
     * @param owner Address that owns the shares
     * @return assets Amount of assets withdrawn
     */
    function redeem(uint256 shares, address receiver, address owner) 
        external 
        nonReentrant 
        moreThanZero(shares) 
        returns (uint256 assets) 
    {
        // Handle allowance if not self-redeeming
        if (owner != msg.sender) {
            uint256 currentAllowance = allowance(owner, msg.sender);
            if (currentAllowance < shares) revert StakeAaveToken__InsufficientShares();
            _approve(owner, msg.sender, currentAllowance - shares);
        }

        // Calculate assets to withdraw
        assets = convertToAssets(shares);
        if (assets == 0) revert StakeAaveToken__InsufficientAssets();

        // Check if we have enough assets
        if (assets > s_totalAssets) revert StakeAaveToken__InsufficientAssets();

        // Effects: Update state
        s_totalAssets -= assets;
        _burn(owner, shares);

        // Interactions: Transfer assets to receiver
        i_asset.safeTransfer(receiver, assets);

        emit Redeem(msg.sender, assets, shares);
    }

    /**
     * @notice Accrue interest to the pool (only lending engine)
     * @param interestAmount Amount of interest to add
     */
    function accrueInterest(uint256 interestAmount) 
        external 
        onlyLendingEngine 
        moreThanZero(interestAmount) 
    {
        // Effects: Add interest to total assets (increases share value)
        s_totalAssets += interestAmount;

        // Transfer interest from lending engine
        i_asset.safeTransferFrom(msg.sender, address(this), interestAmount);

        emit InterestAccrued(s_totalAssets, interestAmount);
    }

    // --- Public View Functions ---

    /**
     * @notice Get the underlying asset address
     * @return Address of the underlying ERC20 token
     */
    function asset() public view returns (address) {
        return address(i_asset);
    }

    /**
     * @notice Get total assets under management
     * @return Total amount of underlying assets
     */
    function totalAssets() public view returns (uint256) {
        return s_totalAssets;
    }

    /**
     * @notice Convert assets to shares
     * @param assets Amount of assets to convert
     * @return shares Equivalent amount of shares
     */
    function convertToShares(uint256 assets) public view returns (uint256 shares) {
        uint256 supply = totalSupply();
        if (supply == 0 || s_totalAssets == 0) {
            return assets; // 1:1 ratio for first deposit
        }
        return (assets * supply) / s_totalAssets;
    }

    /**
     * @notice Convert shares to assets
     * @param shares Amount of shares to convert
     * @return assets Equivalent amount of assets
     */
    function convertToAssets(uint256 shares) public view returns (uint256 assets) {
        uint256 supply = totalSupply();
        if (supply == 0) {
            return shares; // 1:1 ratio if no supply
        }
        return (shares * s_totalAssets) / supply;
    }

    // --- View Functions ---

    /**
     * @notice Get the lending engine address
     * @return Address of the lending engine
     */
    function getLendingEngine() external view returns (address) {
        return s_lendingEngine;
    }
}
