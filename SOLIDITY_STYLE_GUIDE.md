# Solidity Coding Standards & Best Practices

This project follows a strict set of rules for writing and reviewing Solidity smart contracts. All contributions must adhere to these guidelines.

## 1. General Principles

- **Pragma version:** Always use `pragma solidity ^X.Y.Z;` or `pragma solidity >=X.Y.Z <A.B.C;` to lock compiler version.
- **SPDX license identifier:** Always include at the top of every file.
- **Imports:** Group external imports, then internal imports. Use explicit import paths.
- **Comments:** Use NatSpec for all public/external functions and contracts. Use inline comments sparingly but clearly.

## 2. Structure & Layout

- **Sections:** Separate code into Imports, Errors, State Variables, Events, Modifiers, Constructor, External/Public Functions, Internal Functions, Private Functions, View/Pure Functions, Getters.
- **Order:** Functions must be ordered: constructor, external, public, internal, private; within each, order by importance.

## 3. Naming Conventions

- **Contracts:** `CamelCase` (e.g. `DSCEngine`)
- **Functions:** `camelCase` (e.g. `depositCollateral`)
- **Variables:** `camelCase` for local/state, `ALL_CAPS` for constants
- **Events:** `CamelCase` (e.g. `CollateralDeposited`)
- **Errors:** `CamelCase__Description` (e.g. `DSCEngine__NeedsMoreThanZero`)

## 4. Security & Gas

- **Checks-Effects-Interactions:** Always follow this pattern.
- **Reentrancy:** Use `nonReentrant` modifier where needed.
- **Validation:** Use `require`/`revert` with custom errors.
- **Precision:** Use constants for decimals and math precision.

## 5. Functionality

- **Access Control:** Use `onlyOwner` or similar for privileged functions.
- **Visibility:** Explicitly declare visibility for all functions and state variables.
- **Error Handling:** Use custom errors, not just `require` messages.

## 6. Example

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title ExampleContract
/// @notice Demonstrates coding standards for this project
contract ExampleContract {
    // --- Constants ---
    uint256 private constant PRECISION = 1e18;

    // --- State Variables ---
    address public owner;

    // --- Events ---
    event ExampleEvent(address indexed user, uint256 amount);

    // --- Errors ---
    error ExampleContract__NotOwner();

    // --- Modifiers ---
    modifier onlyOwner() {
        if (msg.sender != owner) revert ExampleContract__NotOwner();
        _;
    }

    // --- Constructor ---
    constructor() {
        owner = msg.sender;
    }

    // --- External Functions ---
    /// @notice Example function
    function doSomething(uint256 amount) external onlyOwner {
        // checks-effects-interactions
        require(amount > 0, "Amount must be positive");
        emit ExampleEvent(msg.sender, amount);
    }
}
```

## 7. Linting

- Use [Solhint](https://protofire.github.io/solhint/) for linting.
- Example `.solhint.json`:
```json
{
  "extends": "solhint:recommended",
  "rules": {
    "compiler-version": ["error", "^0.8.0"],
    "func-visibility": ["error", {"ignoreConstructors": false}],
    "const-name-snakecase": "warn",
    "max-line-length": ["warn", 120]
  }
}
```

---

**All PRs will be reviewed for style and security. Please refer to this document before contributing.**