// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { StakeAaveToken } from "./StakeAaveToken.sol";

/**
 * @title StakeAaveETH
 * @author Alex Necsoiu
 * @notice Rebasing token representing staked ETH in the lending protocol
 * @dev Inherits from StakeAaveToken with WETH-specific configurations
 */
contract StakeAaveETH is StakeAaveToken {
    // --- Constructor ---
    /**
     * @notice Initialize the saETH token
     * @param wethToken Address of the WETH token
     * @param owner Address of the contract owner (typically LendingEngine)
     */
    constructor(address wethToken, address owner) 
        StakeAaveToken(wethToken, "Stake Aave ETH", "saETH", owner) 
    {
        // All initialization handled by parent contract
    }
}
