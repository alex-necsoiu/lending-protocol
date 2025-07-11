// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @author Alex Necsoiu
 * @notice Mock ERC20 token for testing purposes
 * @dev Provides minting functionality for testing scenarios
 */
contract MockERC20 is ERC20 {
    uint8 private immutable i_decimals;

    // --- Constructor ---
    /**
     * @notice Initialize the mock token
     * @param name Name of the token
     * @param symbol Symbol of the token
     * @param tokenDecimals Number of decimals for the token
     */
    constructor(
        string memory name,
        string memory symbol,
        uint8 tokenDecimals
    ) ERC20(name, symbol) {
        i_decimals = tokenDecimals;
    }

    // --- External Functions ---

    /**
     * @notice Mint tokens to an address (for testing)
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /**
     * @notice Burn tokens from an address (for testing)
     * @param from Address to burn tokens from
     * @param amount Amount of tokens to burn
     */
    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }

    // --- View Functions ---

    /**
     * @notice Get the number of decimals
     * @return Number of decimals
     */
    function decimals() public view override returns (uint8) {
        return i_decimals;
    }
}
