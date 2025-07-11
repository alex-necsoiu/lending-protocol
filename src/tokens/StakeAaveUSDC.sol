// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { StakeAaveToken } from "./StakeAaveToken.sol";

/**
 * @title StakeAaveUSDC
 * @author Alex Necsoiu
 * @notice Rebasing token representing staked USDC in the lending protocol
 * @dev Inherits from StakeAaveToken with USDC-specific configurations
 */
contract StakeAaveUSDC is StakeAaveToken {
    // --- Constructor ---
    /**
     * @notice Initialize the saUSDC token
     * @param usdcToken Address of the USDC token
     * @param owner Address of the contract owner (typically LendingEngine)
     */
    constructor(address usdcToken, address owner) 
        StakeAaveToken(usdcToken, "Stake Aave USDC", "saUSDC", owner) 
    {
        // All initialization handled by parent contract
    }
}
