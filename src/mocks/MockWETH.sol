// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockWETH
 * @author Alex Necsoiu
 * @notice Mock WETH token for testing purposes
 * @dev Provides minting functionality and ETH wrapping simulation
 */
contract MockWETH is ERC20 {
    // --- Events ---
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    // --- Constructor ---
    constructor() ERC20("Wrapped Ether", "WETH") {}

    // --- External Functions ---

    /**
     * @notice Deposit ETH and receive WETH
     */
    function deposit() external payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Withdraw ETH by burning WETH
     * @param amount Amount of WETH to burn
     */
    function withdraw(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        _burn(msg.sender, amount);
        payable(msg.sender).transfer(amount);
        emit Withdrawal(msg.sender, amount);
    }

    /**
     * @notice Mint WETH tokens (for testing)
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /**
     * @notice Burn WETH tokens (for testing)
     * @param from Address to burn tokens from
     * @param amount Amount of tokens to burn
     */
    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }

    // --- Fallback Functions ---

    /**
     * @notice Receive ETH and mint WETH
     */
    receive() external payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    // --- View Functions ---

    /**
     * @notice WETH has 18 decimals
     * @return Number of decimals (18)
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }
}
