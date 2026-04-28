# Foundry DeFi 智能合约

完整的 DeFi 协议智能合约实现，包括 Swap（AMM）、质押、流动性挖矿、LaunchPad 和 Meme 代币工厂。

## 📁 项目结构

```
foundry-demo/
├── src/                        # 智能合约
│   ├── Swap.sol               # AMM（Uniswap V2 风格）带 LP 代币
│   ├── StakePool.sol          # 单池质押（质押 LP 代币）
│   ├── Farm.sol               # 多池挖矿，支持分配点数
│   ├── LaunchPad.sol          # 代币销售平台
│   ├── MemeToken.sol          # Meme 代币模板（EIP-1167 克隆）
│   ├── MemeFactory.sol        # Meme 代币工厂，自动添加流动性
│   └── tokens/                # ERC20 代币合约
│       ├── RewardToken.sol    # DRT - 奖励代币
│       ├── TokenA.sol         # TKA - 代币 A
│       ├── TokenB.sol         # TKB - 代币 B
│       └── PaymentToken.sol   # USDC - 支付代币
├── script/                    # 部署脚本
│   ├── DeployTokens.s.sol    # 部署所有 ERC20 代币
│   ├── DeployContracts.s.sol # 部署核心合约
│   ├── DeployMemeFactory.s.sol # 部署 MemeFactory
│   └── DeployTokenFactory.s.sol # 部署 TokenFactory
├── test/                      # 测试文件
├── broadcast/                 # 部署记录
└── .env                       # 环境变量
```

## 🚀 快速开始

### 前置要求

安装 Foundry:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 环境配置

在 `foundry-demo/` 目录下创建 `.env` 文件:

```bash
# 私钥（不含 0x 前缀）
PRIVATE_KEY=your_private_key_here

# RPC URLs
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_KEY

# Etherscan API（用于合约验证）
ETHERSCAN_API_KEY=your_etherscan_api_key

# 已部署的合约地址（Sepolia 测试网）
REWARD_TOKEN_ADDRESS=0xb09c7d0757Ed382E2E0F03477671307Dcf7cC30E
TOKEN_A_ADDRESS=0x8a88b830915AEA048Ebf8340ACa47E21b8E342B4
TOKEN_B_ADDRESS=0x2b79645f2Be73db5C001397BA261489DD5D25294
PAYMENT_TOKEN_ADDRESS=0x2d6BF73e7C3c48Ce8459468604fd52303A543dcD
SWAP_ADDRESS=0x6bc3531769f05ea1b99a92c8fb5eb557c3715801
STAKE_POOL_ADDRESS=0x1ad9af9efd7506666200b0748ce9761adf981417
FARM_ADDRESS=0x55cdf982652a9cbca0a738443d3b3ec73f6e2989
LAUNCHPAD_ADDRESS=0xfa0da9d092f0328e5087f5a6400d1a16c0e2970c
MEME_FACTORY_ADDRESS=0x4e6674b70bc7aac1decb3df02f5ebba7ff6735d4
```

### 安装依赖

```bash
cd foundry-demo
forge install
```

### 编译合约

```bash
forge build
```

### 运行测试

```bash
forge test
forge test -vvv  # 详细输出
```

## 📋 合约说明

### 1. Swap.sol - 带 LP 代币的 AMM

**功能**: 自动化做市商（Uniswap V2 风格），合约本身**就是** LP 代币。

**核心特性**:
- 恒定乘积公式: `x * y = k`
- 0.3% 交易手续费
- 首次 1000 个 LP 代币永久锁定
- 继承 ERC20（合约本身就是 LP 代币）

**重要**: 这个合约**就是** LP 代币！它继承自 ERC20，所以当用户添加流动性时，他们收到的 LP 代币就是由这个合约本身铸造的。

**核心函数**:
```solidity
function addLiquidity(uint256 amountA, uint256 amountB) external returns (uint256 liquidity)
function removeLiquidity(uint256 liquidity) external returns (uint256 amountA, uint256 amountB)
function swap(address tokenIn, uint256 amountIn) external returns (uint256 amountOut)
function getAmountOut(address tokenIn, uint256 amountIn) external view returns (uint256)
function getReserves() external view returns (uint256, uint256)
```

**部署参数**:
- `_tokenA`: 第一个代币地址
- `_tokenB`: 第二个代币地址

### 2. StakePool.sol - 单池质押

**功能**: 用户质押 **Swap LP 代币**以赚取**奖励代币**。

**核心特性**:
- 质押代币: Swap LP Token（Swap 合约地址）
- 奖励代币: DRT（RewardToken）
- 基于时间的持续奖励累积
- 奖励率: 每秒 1 个代币（可配置）

**核心函数**:
```solidity
function stake(uint256 amount) external                    // 质押 LP 代币
function withdraw(uint256 amount) external                 // 提取质押的 LP 代币
function getReward() external                              // 领取赚取的奖励
function earned(address account) external view returns (uint256)  // 查看待领取奖励
```

**部署参数**:
- `_stakingToken`: Swap LP 代币地址（Swap 合约地址）
- `_rewardToken`: 奖励代币地址（DRT）
- `_rewardRate`: 每秒奖励数量（1e18 = 1 代币/秒）

**关键配置**: StakePool 合约**必须**拥有足够的奖励代币来分发。部署后，需要向 StakePool 合约转入 DRT 代币。

### 3. Farm.sol - 多池挖矿

**功能**: 用户在**不同的 LP 代币池**中质押，根据分配点数赚取奖励。

**核心特性**:
- 支持多个 LP 代币池
- 分配点数决定奖励分配比例
- 例如：池 0: 30%，池 1: 50%，池 2: 20%
- 奖励率: 每秒 1 个代币（可配置）

**池管理**（仅限所有者）:
```solidity
function add(address _lpToken, uint256 _allocPoint) external onlyOwner  // 添加新池
function set(uint256 _pid, uint256 _allocPoint) external onlyOwner      // 调整池权重
```

**用户函数**:
```solidity
function deposit(uint256 _pid, uint256 _amount) external          // 质押 LP 代币
function withdraw(uint256 _pid, uint256 _amount) external         // 取消质押 LP 代币
function harvest(uint256 _pid) external                           // 领取奖励
function pendingRewards(uint256 _pid, address _user) view returns (uint256)  // 查看待领取奖励
```

**部署参数**:
- `_rewardToken`: 奖励代币地址
- `_rewardRate`: 所有池的总奖励速率（每秒）

### 4. LaunchPad.sol - 代币销售平台

**功能**: 允许项目启动带有可自定义参数的代币销售。

**销售生命周期**:
1. **创建**: 所有者创建带参数的销售
2. **活跃**: 用户在销售期间购买代币
3. **终结**: 所有者终结销售，分发未售出的代币和筹集的资金

**销售参数**:
```solidity
struct Sale {
    address saleToken;      // 销售的代币
    address paymentToken;   // 支付用的代币
    uint256 price;          // 每个代币的价格（wei）
    uint256 totalAmount;    // 销售的总代币数
    uint256 soldAmount;     // 已售出的代币数
    uint256 startTime;      // 销售开始时间戳
    uint256 endTime;        // 销售结束时间戳
    uint256 minPurchase;    // 最小购买数量
    uint256 maxPurchase;    // 每个用户的最大购买量
    bool finalized;         // 销售是否已终结
}
```

**核心函数**:
```solidity
function createSale(...) external onlyOwner               // 创建新销售
function buyTokens(uint256 amount) external               // 购买代币
function claimTokens() external                           // 领取购买的代币
function finalizeSale() external onlyOwner                // 结束销售，分发资金
function getSaleInfo() external view returns (...)        // 获取销售详情
```

### 5. MemeFactory.sol - Meme 代币工厂

**功能**: 使用 EIP-1167 最小代理模式部署 meme 代币，并通过 Uniswap 提供自动流动性。

**核心特性**:
- 通过最小代理克隆减少约 90% 的部署成本
- 自动流动性: 5% 的铸币费用添加到 Uniswap V2 池
- 创建者赚取 95% 的铸币费用
- 支持从 Uniswap 购买功能

**核心函数**:
```solidity
function deployMeme(string symbol, uint256 totalSupply, uint256 perMint, uint256 price) external returns (address)
function mintMeme(address tokenAddr) external payable    // 铸币（5% 到流动性，95% 给创建者）
function buyMeme(address tokenAddr) external payable     // 从 Uniswap 池购买
function getDeployedMemes() external view returns (address[])  // 列出所有部署的 meme
```

**工作原理**:
1. 创建者调用 `deployMeme()` → 创建新的 meme 代币克隆
2. 用户调用 `mintMeme()` → 支付铸币价格 → 获得代币 + 添加流动性到 Uniswap
3. 用户调用 `buyMeme()` → 从 Uniswap 池购买

**部署参数**:
- `_uniswapRouter`: Uniswap V2 Router 地址
- `_weth`: WETH 地址用于流动性配对

### 6. MemeToken.sol - Meme 代币模板

**功能**: 用于最小代理克隆（EIP-1167）的模板合约。

**核心特性**:
- 使用 Initializable 而不是构造函数（用于代理兼容性）
- 固定小数位: 18
- 名称: "Meme Token"
- 符号: 用户定义
- 通过工厂控制铸币

**初始化**:
```solidity
function initialize(
    string memory _symbol,
    address _creator,
    uint256 _totalSupply,
    uint256 _perMint,
    uint256 _price
) external
```

## 🎯 完整部署指南

### 步骤 1: 部署 ERC20 代币

```bash
# 部署 RewardToken, TokenA, TokenB, PaymentToken
forge script script/DeployTokens.s.sol:DeployTokens \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

**部署后**: 使用部署输出更新 `.env` 中的代币地址。

### 步骤 2: 部署核心合约

```bash
# 部署 Swap, StakePool, Farm, LaunchPad
forge script script/DeployContracts.s.sol:DeployContracts \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

**重要**: 此脚本自动:
- 使用 TOKEN_A 和 TOKEN_B 部署 Swap
- 使用 **Swap LP 代币**（而非 TOKEN_A！）部署 StakePool
- 使用奖励代币部署 Farm
- 部署 LaunchPad

**部署后**: 使用合约地址更新 `.env`。

### 步骤 3: 部署 MemeFactory（可选）

```bash
forge script script/DeployMemeFactory.s.sol:DeployMemeFactory \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

**必需参数**（在脚本中）:
- Uniswap V2 Router: `0xC532a74256D3Db42D0Bf7a04139f099D426e0020`（Sepolia）
- WETH: `0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14`（Sepolia）

### 步骤 4: 为合约注资

```bash
# 向 StakePool 转入奖励代币
cast send $REWARD_TOKEN_ADDRESS \
  "transfer(address,uint256)" \
  $STAKE_POOL_ADDRESS \
  1000000000000000000000 \  # 1000 个代币
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY

# 向 Farm 转入奖励代币
cast send $REWARD_TOKEN_ADDRESS \
  "transfer(address,uint256)" \
  $FARM_ADDRESS \
  1000000000000000000000 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 步骤 5: 验证合约（如果自动验证失败）

```bash
# 验证 Swap
forge verify-contract \
  --chain-id 11155111 \
  --watch \
  --constructor-args $(cast abi-encode "constructor(address,address)" $TOKEN_A_ADDRESS $TOKEN_B_ADDRESS) \
  $SWAP_ADDRESS \
  src/Swap.sol:Swap

# 验证 StakePool
forge verify-contract \
  --chain-id 11155111 \
  --watch \
  --constructor-args $(cast abi-encode "constructor(address,address,uint256)" $SWAP_ADDRESS $REWARD_TOKEN_ADDRESS 1000000000000000000) \
  $STAKE_POOL_ADDRESS \
  src/StakePool.sol:StakePool
```

## 🔄 合约替换指南

### 场景 1: 用自己的 Swap 合约替换

**步骤 1**: 在 `src/MySwap.sol` 中创建合约

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MySwap is ERC20 {
    // 你的自定义逻辑
    constructor(address tokenA, address tokenB) ERC20("My LP Token", "MLP") {
        // 你的初始化代码
    }
}
```

**步骤 2**: 更新部署脚本 `script/DeployContracts.s.sol`

```solidity
// 替换:
import "../src/Swap.sol";
Swap swap = new Swap(TOKEN_A, TOKEN_B);

// 改为:
import "../src/MySwap.sol";
MySwap swap = new MySwap(TOKEN_A, TOKEN_B);
```

**步骤 3**: 部署并更新环境

```bash
forge script script/DeployContracts.s.sol:DeployContracts \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv

# 使用新的 SWAP_ADDRESS 更新 .env
```

**步骤 4**: 为前端提取并更新 ABI

```bash
# 提取 ABI
cat out/MySwap.sol/MySwap.json | jq '.abi' > ../web3-dapp/lib/abis/mySwap.json

# 更新 web3-dapp 导入
# 替换: import { SWAP_ABI } from '@/lib/abis/swap'
# 改为: import { SWAP_ABI } from '@/lib/abis/mySwap'
```

### 场景 2: 用自定义质押逻辑替换 StakePool

**步骤 1**: 创建 `src/MyStakePool.sol`

```solidity
pragma solidity ^0.8.20;

contract MyStakePool {
    IERC20 public stakingToken;
    IERC20 public rewardToken;

    constructor(address _stakingToken, address _rewardToken) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
    }

    // 你的自定义质押逻辑
}
```

**步骤 2**: 更新 `script/DeployContracts.s.sol`

```solidity
import "../src/MyStakePool.sol";

MyStakePool stakePool = new MyStakePool(
    address(swap),  // 仍然使用 Swap LP 代币
    REWARD_TOKEN
);
```

**步骤 3**: 部署并提取 ABI

```bash
forge build
forge script script/DeployContracts.s.sol:DeployContracts \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast

# 提取 ABI
jq '.abi' out/MyStakePool.sol/MyStakePool.json > ../web3-dapp/lib/abis/myStakePool.json
```

**步骤 4**: 在 `web3-dapp/app/pool/page.js` 中更新前端

```javascript
// 替换 ABI 导入
import { STAKE_POOL_ABI } from '@/lib/abis/myStakePool'

// 更新 .env 中的合约地址
NEXT_PUBLIC_STAKE_POOL_ADDRESS=0xYourNewAddress
```

### 场景 3: 添加新代币类型

**步骤 1**: 创建代币合约 `src/tokens/MyToken.sol`

```solidity
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {
    constructor() ERC20("My Token", "MTK") {
        _mint(msg.sender, 1000000 * 10**18);
    }
}
```

**步骤 2**: 更新 `script/DeployTokens.s.sol`

```solidity
import "../src/tokens/MyToken.sol";

function run() external {
    vm.startBroadcast(deployerPrivateKey);

    // 添加你的代币
    MyToken myToken = new MyToken();
    console.log("MyToken deployed at:", address(myToken));

    vm.stopBroadcast();
}
```

**步骤 3**: 部署并添加到 `.env`

```bash
forge script script/DeployTokens.s.sol:DeployTokens \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast

# 添加到 .env
MY_TOKEN_ADDRESS=0xYourTokenAddress
```

## 📤 ABI 提取方法

### 方法 1: 使用 jq（推荐）

```bash
# 提取单个合约 ABI
jq '.abi' out/Swap.sol/Swap.json > swap-abi.json

# 格式化提取
jq '.abi' out/Swap.sol/Swap.json | jq '.' > swap-abi-pretty.json

# 批量提取 ABI
for contract in Swap StakePool Farm LaunchPad; do
  jq '.abi' out/$contract.sol/$contract.json > ${contract,,}-abi.json
done
```

### 方法 2: 手动提取

```bash
# 查看完整 JSON
cat out/Swap.sol/Swap.json

# 手动复制 "abi" 数组
# 然后在 VS Code 或在线 JSON 格式化工具中格式化
```

### 方法 3: Forge Inspect

```bash
# 直接获取 ABI
forge inspect Swap abi > swap-abi.json

# 单行 ABI
forge inspect Swap abi --pretty

# 获取字节码
forge inspect Swap bytecode

# 获取存储布局
forge inspect Swap storage-layout
```

### 方法 4: 导出为 JavaScript/TypeScript

创建 `export-abis.js`:
```javascript
const fs = require('fs');

const contracts = ['Swap', 'StakePool', 'Farm', 'LaunchPad', 'MemeFactory'];

contracts.forEach(name => {
  const artifact = require(`./out/${name}.sol/${name}.json`);
  const abi = artifact.abi;

  // 导出为 JavaScript 模块
  const content = `export const ${name.toUpperCase()}_ABI = ${JSON.stringify(abi, null, 2)};`;
  fs.writeFileSync(`../web3-dapp/lib/abis/${name.toLowerCase()}.js`, content);
});

console.log('ABIs 导出成功！');
```

运行:
```bash
node export-abis.js
```

## 🔧 地址替换策略

### 策略 1: 环境变量（推荐）

**在 `.env` 中**:
```bash
SWAP_ADDRESS=0x6bc3531769f05ea1b99a92c8fb5eb557c3715801
STAKE_POOL_ADDRESS=0x1ad9af9efd7506666200b0748ce9761adf981417
```

**在部署脚本中**:
```solidity
address swapAddr = vm.envAddress("SWAP_ADDRESS");
```

**在前端** (`web3-dapp/.env`):
```bash
NEXT_PUBLIC_SWAP_ADDRESS=0x6bc3531769f05ea1b99a92c8fb5eb557c3715801
```

**在 React 中访问**:
```javascript
const swapAddress = process.env.NEXT_PUBLIC_SWAP_ADDRESS
```

### 策略 2: 配置文件

创建 `config/addresses.json`:
```json
{
  "sepolia": {
    "swap": "0x6bc3531769f05ea1b99a92c8fb5eb557c3715801",
    "stakePool": "0x1ad9af9efd7506666200b0748ce9761adf981417",
    "farm": "0x55cdf982652a9cbca0a738443d3b3ec73f6e2989"
  },
  "mainnet": {
    "swap": "0x...",
    "stakePool": "0x...",
    "farm": "0x..."
  }
}
```

**在脚本中使用**:
```solidity
import {stdJson} from "forge-std/StdJson.sol";

string memory json = vm.readFile("config/addresses.json");
address swapAddr = stdJson.readAddress(json, ".sepolia.swap");
```

**在前端使用**:
```javascript
import addresses from '@/config/addresses.json'

const swapAddress = addresses[chainId === 1 ? 'mainnet' : 'sepolia'].swap
```

### 策略 3: 硬编码常量（不推荐）

```solidity
// 在部署脚本中
address constant SWAP_ADDRESS = 0x6bc3531769f05ea1b99a92c8fb5eb557c3715801;
```

**问题**:
- 必须重新编译才能更改
- 跨环境难以维护
- 容易出错

### 策略 4: 解析 Broadcast 文件

部署后，解析 `broadcast/` JSON 文件:

```bash
# 获取最新部署地址
SWAP_ADDR=$(jq -r '.transactions[] | select(.contractName=="Swap") | .contractAddress' \
  broadcast/DeployContracts.s.sol/11155111/run-latest.json)

echo "SWAP_ADDRESS=$SWAP_ADDR" >> .env
```

## 🧪 测试指南

### 运行所有测试

```bash
forge test
```

### 运行特定测试

```bash
forge test --match-test testSwap
forge test --match-contract SwapTest
```

### 详细输出

```bash
forge test -vv      # 显示日志
forge test -vvv     # 显示跟踪
forge test -vvvv    # 显示跟踪 + 设置
forge test -vvvvv   # 显示所有内容
```

### Gas 报告

```bash
forge test --gas-report
```

### 覆盖率

```bash
forge coverage
forge coverage --report lcov  # 生成 lcov 报告
```

### Fork 测试

```bash
# 针对 Sepolia fork 测试
forge test --fork-url $SEPOLIA_RPC_URL

# 测试特定区块
forge test --fork-url $SEPOLIA_RPC_URL --fork-block-number 5000000
```

## 🔍 调试和交互

### 检查合约状态

```bash
# 从 Swap 获取储备
cast call $SWAP_ADDRESS "getReserves()(uint256,uint256)" \
  --rpc-url $SEPOLIA_RPC_URL

# 获取用户质押余额
cast call $STAKE_POOL_ADDRESS "balanceOf(address)(uint256)" \
  0xYourAddress \
  --rpc-url $SEPOLIA_RPC_URL

# 获取用户赚取的奖励
cast call $STAKE_POOL_ADDRESS "earned(address)(uint256)" \
  0xYourAddress \
  --rpc-url $SEPOLIA_RPC_URL
```

### 发送交易

```bash
# 授权代币
cast send $TOKEN_A_ADDRESS \
  "approve(address,uint256)" \
  $SWAP_ADDRESS \
  1000000000000000000 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY

# 向 Swap 添加流动性
cast send $SWAP_ADDRESS \
  "addLiquidity(uint256,uint256)" \
  1000000000000000000 \
  1000000000000000000 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY

# 质押 LP 代币
cast send $STAKE_POOL_ADDRESS \
  "stake(uint256)" \
  1000000000000000000 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 解码交易数据

```bash
# 解码调用数据
cast 4byte 0x095ea7b3  # 返回: approve(address,uint256)

# 解码完整交易
cast tx 0xTransactionHash --rpc-url $SEPOLIA_RPC_URL
```

### 事件日志

```bash
# 从合约获取事件
cast logs \
  --from-block 5000000 \
  --address $SWAP_ADDRESS \
  "Swapped(address,address,uint256,uint256)" \
  --rpc-url $SEPOLIA_RPC_URL
```

## 🛡️ 安全性和验证

### 在 Etherscan 上验证合约

```bash
forge verify-contract \
  --chain-id 11155111 \
  --watch \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --constructor-args $(cast abi-encode "constructor(address,address)" $TOKEN_A_ADDRESS $TOKEN_B_ADDRESS) \
  $SWAP_ADDRESS \
  src/Swap.sol:Swap
```

### 使用 Slither 进行静态分析

```bash
# 安装 slither
pip3 install slither-analyzer

# 运行分析
slither .

# 检查特定合约
slither src/Swap.sol
```

### Gas 优化

```bash
# 生成 gas 快照
forge snapshot

# 比较 gas 变化
forge snapshot --diff .gas-snapshot
```

## 📚 常用命令参考

### 编译

```bash
forge build                    # 编译所有合约
forge build --force            # 强制重新编译
forge clean                    # 清理构建产物
```

### 测试

```bash
forge test                     # 运行所有测试
forge test -vvv                # 详细输出
forge test --gas-report        # 显示 gas 使用
forge coverage                 # 代码覆盖率
```

### 部署

```bash
# 带验证部署
forge script script/Deploy.s.sol:Deploy \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv

# 不带验证部署
forge script script/Deploy.s.sol:Deploy \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast
```

### 合约交互

```bash
cast call <address> "signature(params)" <args> --rpc-url <url>    # 读取
cast send <address> "signature(params)" <args> --rpc-url <url> --private-key <key>  # 写入
cast balance <address> --rpc-url <url>                            # 获取 ETH 余额
cast code <address> --rpc-url <url>                               # 获取字节码
```

### 实用工具

```bash
cast abi-encode "signature(types)" <values>     # 编码调用数据
cast 4byte <selector>                           # 解码函数签名
cast keccak "string"                            # 哈希字符串
cast to-wei <amount> <unit>                     # 转换为 wei
```

## 🐛 故障排除

### 问题: 交换时出现 "Insufficient liquidity"

**原因**: 池中没有流动性或储备不足。

**解决方案**:
```bash
# 检查储备
cast call $SWAP_ADDRESS "getReserves()(uint256,uint256)" --rpc-url $SEPOLIA_RPC_URL

# 先添加流动性
cast send $SWAP_ADDRESS "addLiquidity(uint256,uint256)" 1000000000000000000 1000000000000000000 \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

### 问题: StakePool 中 "No rewards"

**原因**: StakePool 合约没有奖励代币。

**解决方案**:
```bash
# 向 StakePool 转入奖励代币
cast send $REWARD_TOKEN_ADDRESS \
  "transfer(address,uint256)" \
  $STAKE_POOL_ADDRESS \
  1000000000000000000000 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 问题: "Transaction reverted" 没有原因

**原因**: Gas 限制太低或合约错误。

**解决方案**:
```bash
# 先模拟交易
cast call $CONTRACT_ADDRESS "functionName()" --rpc-url $SEPOLIA_RPC_URL

# 使用更高的 gas 限制
cast send $CONTRACT_ADDRESS "functionName()" \
  --gas-limit 500000 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 问题: 验证失败

**原因**: 构造函数参数不匹配或编译器版本不匹配。

**解决方案**:
```bash
# 检查 foundry.toml 中的确切编译器版本
cat foundry.toml | grep solc

# 正确编码构造函数参数
cast abi-encode "constructor(address,address)" $TOKEN_A_ADDRESS $TOKEN_B_ADDRESS

# 使用确切的编译器版本验证
forge verify-contract \
  --chain-id 11155111 \
  --compiler-version v0.8.20+commit.a1b79de6 \
  --constructor-args $(cast abi-encode "constructor(address,address)" $TOKEN_A_ADDRESS $TOKEN_B_ADDRESS) \
  $SWAP_ADDRESS \
  src/Swap.sol:Swap
```

### 问题: "Ownable: caller is not the owner"

**原因**: 从错误的账户调用仅限所有者的函数。

**解决方案**:
```bash
# 检查当前所有者
cast call $CONTRACT_ADDRESS "owner()(address)" --rpc-url $SEPOLIA_RPC_URL

# 使用正确的私钥（部署者的密钥）
cast send $CONTRACT_ADDRESS "ownerFunction()" \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $OWNER_PRIVATE_KEY
```

---

## 🌉 CCIP 跨链桥模块

### 概述

使用 **Chainlink CCIP** (Cross-Chain Interoperability Protocol) 实现 Sepolia ↔ Base Sepolia 双向跨链。

**核心机制**: Burn-Mint 模型
- 源链：Burn (销毁) Token
- 目标链：Mint (铸造) Token
- 保证总供应量守恒

### 📋 已部署合约

#### Sepolia 测试网

| 合约 | 地址 | 说明 |
|------|------|------|
| **CrossChainToken (CCT)** | `0xDC1D17004a2A724d5aa9f6B428C56814aBD156D9` | 跨链 Token |
| **BurnMintTokenPool** | `0x7EbB65FC69F94Cf11f754B102950edab38343536` | Token Pool |

#### Base Sepolia 测试网

| 合约 | 地址 | 说明 |
|------|------|------|
| **CrossChainToken (CCT)** | `0x431306040c181E768C4301a7bfD4fC6a770E833F` | 跨链 Token |
| **BurnMintTokenPool** | `0x27BCD1de1BDd9a40814e2d4BdC500C52c76938e7` | Token Pool |

### 🚀 快速开始

#### 1. 安装依赖

```bash
# 安装 Chainlink CCIP npm 包
npm install @chainlink/contracts@1.4.0 @chainlink/contracts-ccip@1.6.0

# 编译合约
forge build
```

#### 2. 配置环境变量

在 `.env` 文件中添加：

```bash
# RPC URLs
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org

# API Keys (用于合约验证)
ETHERSCAN_API_KEY=your_etherscan_key
BASESCAN_API_KEY=your_basescan_key  # 可选
```

#### 3. 配置 CCIP 参数

编辑 `script/ccip/config.json`：

```json
{
  "BnMToken": {
    "name": "YourTokenName",
    "symbol": "YTN",
    "decimals": 18,
    "maxSupply": 0,
    "preMint": 0,
    "ccipAdminAddress": "YOUR_WALLET_ADDRESS"  // ⚠️ 改为你的地址
  },
  "tokenAmountToMint": 1000000000000000000000,     // 铸造 1000 个
  "tokenAmountToTransfer": 100000000000000000,     // 跨链 0.1 个
  "feeType": "native",                             // 使用 ETH 支付费用
  "remoteChains": {
    "11155111": 84532,    // Sepolia → Base Sepolia
    "84532": 11155111     // Base Sepolia → Sepolia
  }
}
```

### 📝 完整部署流程

CCIP 跨链桥需要在**两条链上**分别部署 Token 和 TokenPool，然后配置跨链参数。

#### 步骤 1-2: 部署 Token（两条链）

```bash
# Sepolia
forge script script/ccip/DeployToken.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast --verify

# Base Sepolia
forge script script/ccip/DeployToken.s.sol \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast --verify
```

#### 步骤 3-4: 部署 TokenPool（两条链）

```bash
# Sepolia
forge script script/ccip/DeployBurnMintTokenPool.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast --verify

# Base Sepolia
forge script script/ccip/DeployBurnMintTokenPool.s.sol \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast --verify
```

#### 步骤 5-6: 配置管理员权限（两条链）

```bash
# Sepolia
forge script script/ccip/ClaimAdmin.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast
forge script script/ccip/AcceptAdminRole.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast

# Base Sepolia
forge script script/ccip/ClaimAdmin.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast
forge script script/ccip/AcceptAdminRole.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast
```

#### 步骤 7-8: 设置跨链配置（两条链）

```bash
# Sepolia
forge script script/ccip/SetPool.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast
forge script script/ccip/ApplyChainUpdates.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast

# Base Sepolia
forge script script/ccip/SetPool.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast
forge script script/ccip/ApplyChainUpdates.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast
```

#### 步骤 9: 铸造测试 Token

```bash
# 在源链（Sepolia）铸造一些 Token 用于测试
forge script script/ccip/MintTokens.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

#### 步骤 10: 执行跨链转账 🚀

```bash
# 从 Sepolia 跨链到 Base Sepolia
forge script script/ccip/TransferTokens.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

**输出示例**：
```
Message ID: 0x12158e8a873e0666f1f37ccd5050562213398e4deb7c7ab9b9fe912364014902
CCIP Explorer: https://ccip.chain.link/msg/12158...
```

### 🔍 验证跨链状态

#### 方法 1: 查询余额

```bash
# 查看 Sepolia 余额（应该减少）
cast call <SEPOLIA_TOKEN_ADDRESS> \
  "balanceOf(address)(uint256)" \
  <YOUR_ADDRESS> \
  --rpc-url $SEPOLIA_RPC_URL

# 查看 Base Sepolia 余额（应该增加）
cast call <BASE_TOKEN_ADDRESS> \
  "balanceOf(address)(uint256)" \
  <YOUR_ADDRESS> \
  --rpc-url $BASE_SEPOLIA_RPC_URL
```

#### 方法 2: 使用 CCIP Explorer

访问 https://ccip.chain.link/msg/<MESSAGE_ID> 查看实时跨链状态。

#### 方法 3: 自动监控脚本

```bash
# 后台运行监控脚本（每 30 秒检查一次）
./script/ccip/CheckCrossChainStatus.sh
```

### 📂 CCIP 文件结构

```
foundry-demo/
├── src/ccip/
│   └── Dependencies.sol           # CCIP 依赖导入
├── script/ccip/
│   ├── config.json               # ⚙️ 配置文件（需修改）
│   ├── HelperConfig.s.sol        # 网络配置
│   ├── utils/HelperUtils.s.sol   # 工具函数
│   ├── DeployToken.s.sol         # 部署 Token
│   ├── DeployBurnMintTokenPool.s.sol  # 部署 TokenPool
│   ├── ClaimAdmin.s.sol          # 声明管理员
│   ├── AcceptAdminRole.s.sol     # 接受管理员
│   ├── SetPool.s.sol             # 设置 Pool 映射
│   ├── ApplyChainUpdates.s.sol   # 配置跨链参数
│   ├── MintTokens.s.sol          # 铸造 Token
│   ├── TransferTokens.s.sol      # 跨链转账
│   ├── CheckCrossChainStatus.sh  # 监控脚本
│   └── output/                   # 部署记录（自动生成）
│       ├── deployedToken_ethereumSepolia.json
│       ├── deployedToken_baseSepolia.json
│       ├── deployedTokenPool_ethereumSepolia.json
│       └── deployedTokenPool_baseSepolia.json
└── node_modules/                 # npm 依赖
    └── @chainlink/               # Chainlink 合约
```

### 🔧 自定义和替换

#### 1. 替换 Token 名称和符号

编辑 `script/ccip/config.json`：

```json
{
  "BnMToken": {
    "name": "MyCustomToken",    // 改为你的 Token 名称
    "symbol": "MCT",            // 改为你的符号
    "ccipAdminAddress": "0x..." // 改为你的地址
  }
}
```

#### 2. 添加更多支持的链

在 `config.json` 的 `remoteChains` 中添加：

```json
{
  "remoteChains": {
    "11155111": 84532,      // Sepolia → Base Sepolia
    "84532": 11155111,      // Base → Sepolia
    "421614": 11155111      // Arbitrum Sepolia → Sepolia (示例)
  }
}
```

然后在 `script/ccip/HelperConfig.s.sol` 中添加对应链的配置。

#### 3. 使用自己的 Token 合约

如果你已有 ERC20 Token，只需：
1. 确保它支持 `burn()` 和 `mint()` 函数
2. 跳过 `DeployToken.s.sol` 脚本
3. 手动创建 `deployedToken_<chainName>.json` 文件
4. 从 `DeployBurnMintTokenPool.s.sol` 开始执行

#### 4. 配置速率限制器

编辑 `ApplyChainUpdates.s.sol`，修改 `RateLimiter.Config`：

```solidity
outboundRateLimiterConfig: RateLimiter.Config({
    isEnabled: true,            // 启用速率限制
    capacity: 1000e18,          // 最大容量 1000 Token
    rate: 10e18                 // 每秒补充 10 Token
})
```

### 💰 Gas 费用估算

| 操作 | Sepolia | Base Sepolia | 说明 |
|------|---------|--------------|------|
| 部署 Token | ~0.000002 ETH | ~0.000004 ETH | 一次性 |
| 部署 TokenPool | ~0.000004 ETH | ~0.00001 ETH | 一次性 |
| 配置管理员 | ~0.0000003 ETH | ~0.0000006 ETH | 一次性 |
| 配置跨链 | ~0.0000005 ETH | ~0.000001 ETH | 一次性 |
| **跨链转账** | ~0.00004 ETH | - | **每次** |
| **CCIP 费用** | ~0.00008 ETH | - | **每次** |

**总部署成本**: ~0.00015 ETH (两条链)
**单次跨链成本**: ~0.00012 ETH

### ⚠️ 注意事项

1. **测试网 Token 不具有价值**：所有操作均在测试网进行。

2. **跨链时间**：CCIP 跨链通常需要 5-15 分钟，具体取决于网络拥堵情况。

3. **Gas 费用准备**：
   - Sepolia 账户需要至少 0.5 ETH
   - Base Sepolia 账户需要至少 0.5 ETH
   - 从水龙头获取:
     - Sepolia: https://sepoliafaucet.com/
     - Base Sepolia: https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet

4. **管理员地址**：`config.json` 中的 `ccipAdminAddress` 必须与部署账户一致。

5. **合约验证**：使用 `--verify` 标志需要有效的 API Key。

6. **安全提示**：
   - 永远不要在生产环境使用测试网私钥
   - 生产部署前需要专业的安全审计
   - 定期检查 Chainlink CCIP 文档更新

### 📚 参考资源

- **Chainlink CCIP 文档**: https://docs.chain.link/ccip
- **CCIP Explorer**: https://ccip.chain.link/
- **支持的网络**: https://docs.chain.link/ccip/supported-networks
- **Burn-Mint Token 标准**: https://docs.chain.link/ccip/tutorials/cross-chain-tokens
- **Token Pool 配置**: https://docs.chain.link/ccip/architecture#token-pools

### 🐛 故障排查

<details>
<summary><strong>编译错误: 找不到 @chainlink/contracts-ccip</strong></summary>

```bash
# 重新安装依赖
npm install @chainlink/contracts@1.4.0 @chainlink/contracts-ccip@1.6.0

# 清理并重新编译
forge clean
forge build
```
</details>

<details>
<summary><strong>跨链卡住，长时间未完成</strong></summary>

1. 访问 CCIP Explorer 查看状态
2. 检查源链 Token 是否已 burn（余额减少）
3. 等待 15-20 分钟后再次检查
4. 如果仍未完成，检查 CCIP 网络状态: https://status.chain.link/
</details>

<details>
<summary><strong>权限错误: "Only admin can perform this action"</strong></summary>

确保:
1. `config.json` 中的 `ccipAdminAddress` 是你的钱包地址
2. 已执行 `ClaimAdmin.s.sol` 和 `AcceptAdminRole.s.sol`
3. 使用正确的私钥执行脚本
</details>

<details>
<summary><strong>Gas 估算失败或交易 revert</strong></summary>

1. 检查账户 ETH 余额是否充足
2. 确认 RPC URL 正常工作
3. 尝试增加 gas limit: `--gas-limit 500000`
4. 检查是否按顺序执行了所有步骤
</details>

---

## 📖 其他资源

- **Foundry Book**: https://book.getfoundry.sh/
- **OpenZeppelin Contracts**: https://docs.openzeppelin.com/contracts/
- **Solidity Docs**: https://docs.soliditylang.org/
- **Uniswap V2 Docs**: https://docs.uniswap.org/protocol/V2/introduction
- **EIP-1167 (Minimal Proxy)**: https://eips.ethereum.org/EIPS/eip-1167

## 🤝 贡献

这是一个教育项目。欢迎:
- 用你自己的实现替换合约
- 修改部署脚本
- 添加新功能和模块
- 试验不同的 DeFi 机制

## 📄 许可证

MIT License - 详见 LICENSE 文件
