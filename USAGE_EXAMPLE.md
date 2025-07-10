# 🎯 Lending Protocol Usage Example

## 📋 Prerequisites

1. Deploy the protocol (see deployment section)
2. Have some USDC/WETH/MATIC tokens
3. Contract addresses from deployment

## 🔄 User Journey Example

### Step 1: Initial Setup
```solidity
// Contract instances (from deployment)
LendingEngine lendingEngine = LendingEngine(0x...);
IERC20 usdc = IERC20(0x...);
IStakeAaveToken saUSDC = IStakeAaveToken(0x...);
```

### Step 2: User Deposits Assets
```solidity
// User has 1000 USDC and wants to earn interest
uint256 depositAmount = 1000e6; // 1000 USDC (6 decimals)

// Step 2a: Approve LendingEngine to spend USDC
usdc.approve(address(lendingEngine), depositAmount);

// Step 2b: Deposit USDC and receive saUSDC tokens
uint256 sharesReceived = lendingEngine.deposit(address(usdc), depositAmount);

// User now has saUSDC tokens worth 1000 USDC
assert(saUSDC.balanceOf(user) == sharesReceived);
assert(saUSDC.convertToAssets(sharesReceived) == depositAmount);
```

### Step 3: Interest Accrues
```solidity
// Protocol earns 5% yield (50 USDC) 
// Admin/Protocol calls:
lendingEngine.simulateInterest(address(usdc), 50e6);

// User's shares now worth more!
uint256 userAssets = saUSDC.convertToAssets(saUSDC.balanceOf(user));
// userAssets = 1050 USDC (original 1000 + 50 interest)
```

### Step 4: User Redeems with Interest
```solidity
// User wants to withdraw all assets
uint256 userShares = saUSDC.balanceOf(user);

// Step 4a: Approve LendingEngine to burn shares
saUSDC.approve(address(lendingEngine), userShares);

// Step 4b: Redeem shares for underlying assets
uint256 assetsReceived = lendingEngine.redeem(address(usdc), userShares);

// User receives 1050 USDC (1000 original + 50 interest)
assert(assetsReceived == 1050e6);
```

## 🔢 Mathematical Example

### Initial State
- User deposits: 1000 USDC
- Shares received: 1000 saUSDC (1:1 ratio)
- Total pool: 1000 USDC
- Share price: 1.0

### After Interest
- Interest added: 50 USDC
- Total pool: 1050 USDC  
- User shares: 1000 saUSDC (unchanged)
- New share price: 1050/1000 = 1.05
- User asset value: 1000 shares × 1.05 = 1050 USDC

### Multiple Users Example
```
User A deposits: 600 USDC → gets 600 shares
User B deposits: 400 USDC → gets 400 shares
Total pool: 1000 USDC, 1000 shares

Interest added: 100 USDC
New total pool: 1100 USDC, 1000 shares
New share price: 1100/1000 = 1.1

User A value: 600 shares × 1.1 = 660 USDC (60 USDC profit)
User B value: 400 shares × 1.1 = 440 USDC (40 USDC profit)
```

## 🛠️ Advanced Usage

### Multi-Asset Portfolio
```solidity
// Deposit across multiple assets
lendingEngine.deposit(address(usdc), 1000e6);   // USDC
lendingEngine.deposit(address(weth), 1e18);     // WETH  
lendingEngine.deposit(address(matic), 1000e18); // MATIC

// Each asset earns interest independently
// User gets saUSDC, saETH, saMATIC tokens
```

### Direct Token Interaction (ERC4626)
```solidity
// Users can also interact directly with protocol tokens
saUSDC.deposit(1000e6, user);                   // Direct deposit
saUSDC.redeem(shares, user, user);              // Direct redeem
```

## 📊 Monitoring & Analytics

### Check Your Position
```solidity
// Get user's share balance
uint256 shares = saUSDC.balanceOf(user);

// Get current asset value
uint256 assetValue = saUSDC.convertToAssets(shares);

// Calculate profit/loss
uint256 profit = assetValue - originalDeposit;

// Get current share price
uint256 sharePrice = lendingEngine.getSharePrice(address(usdc));
```

### Protocol Statistics
```solidity
// Total assets in USDC pool
uint256 totalAssets = saUSDC.totalAssets();

// Total shares issued
uint256 totalShares = saUSDC.totalSupply();

// Current exchange rate
uint256 exchangeRate = totalAssets * 1e18 / totalShares;
```

## ⚠️ Important Notes

1. **Rebasing**: Your token balance stays the same, but each token becomes worth more
2. **Interest Distribution**: Interest is distributed proportionally to all holders
3. **No Lock-up**: You can deposit/withdraw anytime
4. **Gas Costs**: Consider gas costs for small transactions
5. **Slippage**: Large transactions might affect share price slightly

## 🔍 Verification Steps

Always verify:
1. Transaction succeeded
2. Token balances updated correctly  
3. Share price increased after interest
4. No unexpected fees deducted

## 🆘 Troubleshooting

Common issues:
- **Insufficient Allowance**: Remember to approve tokens
- **Insufficient Balance**: Check your token balance
- **Asset Not Supported**: Verify asset is whitelisted
- **Zero Amount**: Cannot deposit/redeem 0 tokens
