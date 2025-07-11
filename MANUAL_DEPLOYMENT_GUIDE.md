# Manual Deployment Guide for Lending Protocol

## Prerequisites

1. **Install Foundry**: Make sure you have Foundry installed
2. **Clone the repository**: Have the project files ready
3. **Terminal access**: Two terminals recommended (one for Anvil, one for commands)

## Step 1: Start Anvil (Local Blockchain)

In your first terminal:
```bash
# Navigate to project directory
cd /path/to/lending-protocol

# Start Anvil local blockchain
anvil --host 0.0.0.0 --port 8545
```

This will start a local blockchain with:
- 10 pre-funded accounts (10,000 ETH each)
- Chain ID: 31337
- RPC URL: http://localhost:8545

**Important addresses from Anvil:**
- Account 0: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`
- Private Key: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`

## Step 2: Deploy Contracts

In your second terminal:
```bash
# Navigate to project directory  
cd /path/to/lending-protocol

# Deploy all contracts using the deployment script
forge script script/DeployLending.s.sol \
    --rpc-url http://localhost:8545 \
    --broadcast \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    -vv
```

This will deploy:
- **Mock USDC**: ERC20 token with 6 decimals
- **Mock WETH**: ERC20 token with 18 decimals  
- **Mock MATIC**: ERC20 token with 18 decimals
- **LendingEngine**: Main protocol contract
- **saUSDC**: Stake Aave USDC token
- **saETH**: Stake Aave ETH token
- **saMATIC**: Stake Aave MATIC token

## Step 3: Record Deployed Addresses

From the deployment output, save these addresses:

```
=== DEPLOYED CONTRACTS ===
LendingEngine: 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9
saUSDC: 0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9
saETH: 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707
saMATIC: 0x0165878A594ca255338adfa4d48449f69242Eb8F
USDC: 0x5FbDB2315678afecb367f032d93F642f64180aa3
WETH: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
MATIC: 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
```

## Step 4: Test the Protocol

Run the interaction script:
```bash
forge script script/InteractWithProtocol.s.sol \
    --rpc-url http://localhost:8545 \
    --broadcast \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    -vv
```

This will:
1. Mint 10,000 USDC to the user
2. Deposit 1,000 USDC into the protocol
3. Simulate 50 USDC interest accrual
4. Redeem half of the shares

## Step 5: Manual Interaction with Cast

You can also interact with contracts directly using `cast`:

### Check Balances
```bash
# Check user's USDC balance
cast call 0x5FbDB2315678afecb367f032d93F642f64180aa3 \
    "balanceOf(address)" \
    0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
    --rpc-url http://localhost:8545

# Check user's saUSDC balance
cast call 0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9 \
    "balanceOf(address)" \
    0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
    --rpc-url http://localhost:8545
```

### Check Protocol State
```bash
# Check share price for USDC
cast call 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 \
    "getSharePrice(address)" \
    0x5FbDB2315678afecb367f032d93F642f64180aa3 \
    --rpc-url http://localhost:8545

# Check total assets in saUSDC
cast call 0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9 \
    "totalAssets()" \
    --rpc-url http://localhost:8545
```

### Make Transactions
```bash
# Mint USDC to user
cast send 0x5FbDB2315678afecb367f032d93F642f64180aa3 \
    "mint(address,uint256)" \
    0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
    1000000000 \
    --rpc-url http://localhost:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Approve LendingEngine to spend USDC
cast send 0x5FbDB2315678afecb367f032d93F642f64180aa3 \
    "approve(address,uint256)" \
    0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 \
    1000000000 \
    --rpc-url http://localhost:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Deposit USDC into protocol
cast send 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 \
    "deposit(address,uint256)" \
    0x5FbDB2315678afecb367f032d93F642f64180aa3 \
    1000000000 \
    --rpc-url http://localhost:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

## Step 6: Verify Deployment

### Check Contract Verification
```bash
# Verify LendingEngine deployment
cast code 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 --rpc-url http://localhost:8545

# Check if saUSDC is properly linked to LendingEngine
cast call 0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9 \
    "getLendingEngine()" \
    --rpc-url http://localhost:8545
```

### Check Protocol Configuration
```bash
# Check if USDC is supported
cast call 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 \
    "s_supportedAssets(address)" \
    0x5FbDB2315678afecb367f032d93F642f64180aa3 \
    --rpc-url http://localhost:8545

# Check asset to token mapping
cast call 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 \
    "s_assetToStakeToken(address)" \
    0x5FbDB2315678afecb367f032d93F642f64180aa3 \
    --rpc-url http://localhost:8545
```

## Step 7: Run Tests

```bash
# Run all tests
forge test -vv

# Run specific test file
forge test --match-path test/unit/LendingEngineTest.t.sol -vv

# Run integration tests
forge test --match-path test/integration/FullFlowTest.t.sol -vv
```

## Troubleshooting

### Common Issues

1. **Port already in use**: Kill existing Anvil processes
```bash
pkill -f anvil
```

2. **Transaction reverted**: Check gas limits and balances
```bash
cast balance 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --rpc-url http://localhost:8545
```

3. **Contract not found**: Verify deployment was successful
```bash
cast code [CONTRACT_ADDRESS] --rpc-url http://localhost:8545
```

### Useful Commands

```bash
# Get transaction receipt
cast receipt [TX_HASH] --rpc-url http://localhost:8545

# Get block info
cast block latest --rpc-url http://localhost:8545

# Convert hex to decimal
cast to-dec [HEX_VALUE]

# Convert decimal to hex
cast to-hex [DECIMAL_VALUE]

# Convert wei to ether
cast from-wei [WEI_VALUE]
```

## Next Steps

1. **Deploy to Testnet**: Modify the deployment script for Sepolia/Goerli
2. **Add Frontend**: Create a web interface to interact with the protocol
3. **Add More Assets**: Deploy additional StakeAave tokens
4. **Implement Governance**: Add protocol parameter management
5. **Add Liquidation**: Implement liquidation mechanisms

## Security Considerations

- Never use the provided private keys in production
- Always verify contract addresses before interacting
- Test thoroughly on testnets before mainnet deployment
- Consider formal verification for production contracts
- Implement proper access controls and emergency stops

## Protocol Flow Summary

1. **User deposits** → Receives shares representing their stake
2. **Interest accrues** → Share price increases (rebasing effect)
3. **User redeems** → Burns shares, receives proportional assets + interest
4. **Protocol grows** → More assets, higher yields, more users

The protocol successfully demonstrates:
- ✅ ERC4626-compatible vaults
- ✅ Rebasing token mechanics
- ✅ Interest accrual simulation
- ✅ Multi-asset support
- ✅ Complete DeFi lending flow
