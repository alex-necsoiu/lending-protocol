// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { StakeAaveToken } from "./StakeAaveToken.sol";

/**
 * @title StakeAaveMATIC
 * @author Alex Necsoiu
 * @notice Rebasing token representing staked MATIC in the lending protocol
 * @dev Inherits from StakeAaveToken with MATIC-specific configurations
 */
contract StakeAaveMATIC is StakeAaveToken {
    // --- Constructor ---
    /**
     * @notice Initialize the saMATIC token
     * @param maticToken Address of the MATIC token
     * @param owner Address of the contract owner (typically LendingEngine)
     */
    constructor(address maticToken, address owner) 
        StakeAaveToken(maticToken, "Stake Aave MATIC", "saMATIC", owner) 
    {
        // All initialization handled by parent contract
    }
}
