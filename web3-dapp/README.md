# Web3 DApp - DeFi 教学平台

基于 Next.js 的综合性去中心化金融（DeFi）应用，用于教育目的，包含 LaunchPad、Meme Factory、Bridge、DEX（Swap）、LP 质押（Pool）和多池挖矿模块。

## 📋 目录

- [技术栈](#技术栈)
- [功能特性](#功能特性)
- [项目结构](#项目结构)
- [快速开始](#快速开始)
- [环境配置](#环境配置)
- [页面替换指南](#页面替换指南)
- [ABI 管理](#abi-管理)
- [合约集成](#合约集成)
- [组件复用](#组件复用)
- [部署](#部署)
- [故障排除](#故障排除)

## 🛠 技术栈

### 前端框架
- **Next.js 15** (App Router) - 支持服务端渲染的 React 框架
- **JavaScript** - 纯 JS 实现（为教学简化，不使用 TypeScript）
- **Tailwind CSS** - 实用优先的 CSS 框架
- **shadcn/ui** - 可复用的 UI 组件库

### Web3 库
- **wagmi v2** - 以太坊 React Hooks
- **viem v2** - 以太坊 TypeScript 接口
- **RainbowKit** - 多钱包支持的钱包连接 UI
- **@metamask/sdk-react** - MetaMask SDK 集成

### 数据可视化
- **ECharts** - 交互式图表（仅客户端，避免 SSR 问题）

### 智能合约
- **Foundry** - 合约开发框架
- **OpenZeppelin** - 安全合约库
- **Sepolia Testnet** - 部署网络

## ✨ 功能特性

### 1. LaunchPad（传统 + Meme Factory）

**传统 LaunchPad**:
- 创建可自定义参数的代币销售
- 在销售期间购买代币
- 销售结束后领取购买的代币
- 实时进度跟踪（已售/总量）
- 销售开始/结束倒计时

**Meme Factory 模式**:
- 使用 EIP-1167 最小代理部署 meme 代币（节省约 90% gas）
- 自动流动性提供的铸币（5% 到 Uniswap）
- 直接从 Uniswap 池购买
- 创建者费用分配（95% 给创建者，5% 到流动性）

**关键文件**:
- `/app/launchpad/page.js` - LaunchPad 列表页
- `/app/launchpad/create/page.js` - 创建销售（传统 + meme 模式）
- `/app/launchpad/[id]/page.js` - 销售详情页
- `/lib/abis/launchpad.js` - LaunchPad ABI
- `/lib/abis/memeFactory.js` - MemeFactory + MemeToken ABIs

### 2. Bridge（CCIP 跨链桥）

**功能**:
- **Sepolia ↔ Base Sepolia 双向跨链**
- 使用 **Chainlink CCIP** 协议确保安全可靠
- 支持 CCT (CrossChainToken) 跨链转账
- 实时余额查询（源链 + 目标链）
- 跨链进度追踪（CCIP Explorer 集成）
- 自动切换网络功能
- ERC20 授权流程处理

**关键文件**:
- `/app/bridge/page.js` - CCIP Bridge 界面
- `/lib/abis/ccip/BurnMintERC20.json` - CCT 代币 ABI
- `/lib/abis/ccip/IRouterClient.json` - CCIP Router ABI

**重要配置**:
- 源链: Sepolia (Chain ID: 11155111)
- 目标链: Base Sepolia (Chain ID: 84532)
- CCT Token (Sepolia): 0xDC1D17004a2A724d5aa9f6B428C56814aBD156D9
- CCT Token (Base Sepolia): 0x431306040c181E768C4301a7bfD4fC6a770E833F
- CCIP Router (Sepolia): 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59
- CCIP Router (Base Sepolia): 0xD3b06cEbF099CE7DA4AcCf578aaebFDBd6e88a93

**跨链流程**:
1. 用户在源链授权 CCT 代币给 CCIP Router
2. 用户发起跨链转账（支付 Gas + CCIP 费用）
3. 源链 burn 代币，生成 CCIP Message ID
4. CCIP 网络验证并转发消息（5-15 分钟）
5. 目标链 mint 等量代币到接收地址

### 3. DEX Swap（AMM）

**功能**:
- 恒定乘积 AMM 代币交换（`x * y = k`）
- 实时价格计算
- 滑点保护和价格影响显示
- 0.3% 交易手续费
- 代币授权处理

**关键文件**:
- `/app/swap/page.js` - Swap 界面
- `/lib/abis/swap.js` - Swap 合约 ABI
- 使用 `Swap.sol` 合约（合约本身就是 LP 代币）

### 4. Pool（LP 质押）

**功能**:
- 双代币输入添加流动性
- 按比例移除流动性
- 质押 LP 代币赚取奖励
- 提取质押的 LP 代币
- 领取累积奖励
- 实时 APY 计算
- 待领取奖励显示

**重要**: 质押代币是 **Swap LP Token**（Swap 合约地址），不是 TOKEN_A！

**关键文件**:
- `/app/pool/page.js` - Pool 界面
- `/lib/abis/stakePool.js` - StakePool 合约 ABI
- 使用 `StakePool.sol` 合约

### 5. Farm（多池挖矿）

**功能**:
- 具有分配点数的多个 LP 代币池
- 存入/提取 LP 代币
- 从单个池收获奖励
- 一次性收获所有奖励
- 实时 APY 和 TVL 计算
- 每个池的待领取奖励

**关键文件**:
- `/app/farm/page.js` - Farm 界面
- `/app/api/farm/stats/route.js` - Farm 统计 API
- `/lib/abis/farm.js` - Farm 合约 ABI
- 使用 `Farm.sol` 合约

### 6. Dashboard

**功能**:
- 总价值的投资组合概览
- 钱包代币余额
- LP 代币持有量
- Pool 和 Farm 中的质押头寸
- 价格图表（7 天、30 天历史数据）
- TVL 和交易量图表
- 代币统计卡片

**关键文件**:
- `/app/dashboard/page.js` - Dashboard 页面
- `/components/charts/PriceChart.js` - ECharts 价格图表
- `/components/charts/TVLChart.js` - ECharts TVL 图表
- `/app/api/token/price/route.js` - 价格数据 API

## 📁 项目结构

```
web3-dapp/
├── app/
│   ├── api/                           # API 路由处理器（无服务器函数）
│   │   ├── bridge/transfer/route.js   # Bridge API
│   │   ├── farm/stats/route.js        # Farm 统计
│   │   ├── health/route.js            # 健康检查端点
│   │   ├── launchpad/projects/route.js # LaunchPad 项目列表
│   │   ├── network/route.js           # 网络状态（RPC 延迟、费用）
│   │   ├── stake/pools/route.js       # 质押池数据
│   │   └── token/price/route.js       # 代币价格历史
│   ├── bridge/page.js                 # Bridge 页面
│   ├── dashboard/page.js              # Dashboard 页面
│   ├── farm/page.js                   # Farm 页面
│   ├── launchpad/
│   │   ├── page.js                    # LaunchPad 列表
│   │   ├── create/page.js             # 创建销售（传统 + meme 模式）
│   │   └── [id]/page.js               # 销售详情页
│   ├── pool/page.js                   # LP 质押页面
│   ├── swap/page.js                   # DEX Swap 页面
│   ├── layout.js                      # 带 Web3 提供者的根布局
│   ├── page.js                        # 主页
│   └── globals.css                    # 全局样式
├── components/
│   ├── charts/
│   │   ├── PriceChart.js              # 代币价格图表（ECharts）
│   │   └── TVLChart.js                # TVL 图表（ECharts）
│   ├── ui/                            # shadcn/ui 组件
│   │   ├── button.jsx
│   │   ├── card.jsx
│   │   ├── input.jsx
│   │   ├── select.jsx
│   │   └── tabs.jsx
│   ├── ApproveButton.js               # ERC20 授权组件
│   ├── Navbar.js                      # 导航栏
│   └── Providers.js                   # Web3 提供者包装器
├── lib/
│   ├── abis/                          # 合约 ABIs（从 Foundry 导出）
│   │   ├── erc20.js                   # ERC20 ABI
│   │   ├── farm.js                    # Farm ABI
│   │   ├── launchpad.js               # LaunchPad ABI
│   │   ├── memeFactory.js             # MemeFactory + MemeToken ABIs
│   │   ├── stakePool.js               # StakePool ABI
│   │   └── swap.js                    # Swap ABI
│   ├── wagmiClient.js                 # Wagmi 配置
│   └── utils.js                       # 实用函数
├── public/                            # 静态资源
├── .env                               # 环境变量（已提交，用于 Vercel）
├── .env.local                         # 本地环境变量（已忽略）
├── next.config.mjs                    # Next.js 配置
├── tailwind.config.js                 # Tailwind CSS 配置
└── package.json                       # 依赖项
```

## 🚀 快速开始

### 前置要求

- **Node.js 18+** 和 npm/yarn/pnpm
- **MetaMask** 或兼容的 Web3 钱包
- **Sepolia 测试网 ETH** ([从水龙头获取](https://sepoliafaucet.com/))

### 安装

```bash
cd web3-dapp
npm install
```

### 运行开发服务器

```bash
npm run dev
# 打开 http://localhost:3000
```

### 构建生产版本

```bash
npm run build
npm start
```

## 🔧 环境配置

### 环境变量

在 `web3-dapp/` 目录下创建 `.env.local`:

```bash
# Wallet Connect（RainbowKit 必需）
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=your_project_id_from_walletconnect_cloud

# RPC URLs（可选 - 默认使用公共 RPC）
NEXT_PUBLIC_RPC_URL_SEPOLIA=https://sepolia.infura.io/v3/YOUR_INFURA_KEY
NEXT_PUBLIC_RPC_URL_MAINNET=https://mainnet.infura.io/v3/YOUR_INFURA_KEY

# 合约地址（Sepolia 测试网）
NEXT_PUBLIC_REWARD_TOKEN_ADDRESS=0xb09c7d0757Ed382E2E0F03477671307Dcf7cC30E
NEXT_PUBLIC_TOKEN_A_ADDRESS=0x8a88b830915AEA048Ebf8340ACa47E21b8E342B4
NEXT_PUBLIC_TOKEN_B_ADDRESS=0x2b79645f2Be73db5C001397BA261489DD5D25294
NEXT_PUBLIC_PAYMENT_TOKEN_ADDRESS=0x2d6BF73e7C3c48Ce8459468604fd52303A543dcD
NEXT_PUBLIC_SWAP_ADDRESS=0x6bc3531769f05ea1b99a92c8fb5eb557c3715801
NEXT_PUBLIC_STAKE_POOL_ADDRESS=0x1ad9af9efd7506666200b0748ce9761adf981417
NEXT_PUBLIC_FARM_ADDRESS=0x55cdf982652a9cbca0a738443d3b3ec73f6e2989
NEXT_PUBLIC_LAUNCHPAD_ADDRESS=0xfa0da9d092f0328e5087f5a6400d1a16c0e2970c
NEXT_PUBLIC_TOKEN_FACTORY_ADDRESS=0x27345a45c0cbd8e780650ae59DF8f18eb5aB376D
NEXT_PUBLIC_MEME_FACTORY_ADDRESS=0x4e6674b70bc7aac1decb3df02f5ebba7ff6735d4

# 可选: API Keys
NEXT_PUBLIC_ETHERSCAN_API_KEY=your_etherscan_api_key
```

### 获取 WalletConnect Project ID

1. 访问 [WalletConnect Cloud](https://cloud.walletconnect.com/)
2. 注册/登录
3. 创建新项目
4. 复制 **Project ID**
5. 添加到 `.env.local` 作为 `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID`

## 🔄 页面替换指南

### 场景 1: 用自定义 DEX 逻辑替换 Swap 页面

**步骤 1**: 理解当前 Swap 页面结构

当前文件: `/app/swap/page.js`

关键部分:
- 状态管理（代币选择、数量）
- 合约交互（swap、approve）
- 价格计算和显示
- 交易处理

**步骤 2**: 创建自定义 Swap 实现

```javascript
// app/my-swap/page.js
'use client'

import { useState } from 'react'
import { useAccount, useReadContract, useWriteContract } from 'wagmi'
import { parseUnits, formatUnits } from 'viem'
import { SWAP_ABI } from '@/lib/abis/swap'

export default function MySwapPage() {
  const { address } = useAccount()
  const [tokenIn, setTokenIn] = useState('TKA')
  const [amountIn, setAmountIn] = useState('')
  const [amountOut, setAmountOut] = useState('0')

  const swapAddress = process.env.NEXT_PUBLIC_SWAP_ADDRESS

  // 你的自定义逻辑
  const handleSwap = async () => {
    // 自定义 swap 实现
  }

  return (
    <div className="container mx-auto p-6">
      <h1>我的自定义 Swap</h1>
      {/* 你的自定义 UI */}
    </div>
  )
}
```

**步骤 3**: 在 `components/Navbar.js` 中更新导航

```javascript
// 替换这个链接:
{ name: 'Swap', href: '/swap' }

// 改为:
{ name: 'Swap', href: '/my-swap' }
```

**步骤 4**: （可选）删除旧的 swap 页面

```bash
rm app/swap/page.js
# 或保留两者以进行比较
```

### 场景 2: 添加新交易页面（例如，期权、期货）

**步骤 1**: 在 `foundry-demo/src/Options.sol` 中创建新合约

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Options {
    function buyOption(uint256 strikePrice, uint256 expiry) external payable {
        // 你的期权逻辑
    }
}
```

**步骤 2**: 部署合约并提取 ABI

```bash
cd ../foundry-demo
forge build
jq '.abi' out/Options.sol/Options.json > ../web3-dapp/lib/abis/options.json
```

**步骤 3**: 创建 ABI JavaScript 导出

```javascript
// lib/abis/options.js
export const OPTIONS_ABI = [
  // 从 options.json 粘贴 ABI
  {
    "type": "function",
    "name": "buyOption",
    "inputs": [
      {"name": "strikePrice", "type": "uint256"},
      {"name": "expiry", "type": "uint256"}
    ],
    "outputs": [],
    "stateMutability": "payable"
  }
]
```

**步骤 4**: 在 `/app/options/page.js` 创建页面

```javascript
'use client'

import { useWriteContract } from 'wagmi'
import { OPTIONS_ABI } from '@/lib/abis/options'

export default function OptionsPage() {
  const { writeContract } = useWriteContract()

  const buyOption = async (strikePrice, expiry) => {
    await writeContract({
      address: process.env.NEXT_PUBLIC_OPTIONS_ADDRESS,
      abi: OPTIONS_ABI,
      functionName: 'buyOption',
      args: [strikePrice, expiry],
      value: parseUnits('0.1', 18) // 溢价支付
    })
  }

  return (
    <div className="container mx-auto p-6">
      <h1>期权交易</h1>
      {/* 你的期权 UI */}
    </div>
  )
}
```

**步骤 5**: 添加到导航

```javascript
// components/Navbar.js
const navItems = [
  { name: 'Dashboard', href: '/dashboard' },
  { name: 'Swap', href: '/swap' },
  { name: 'Options', href: '/options' }, // 新增!
  // ...
]
```

**步骤 6**: 添加环境变量

```bash
# .env.local
NEXT_PUBLIC_OPTIONS_ADDRESS=0xYourOptionsContractAddress
```

## 📦 ABI 管理

### 理解 ABI 结构

ABI（应用程序二进制接口）定义了如何与智能合约交互。每个函数、事件和错误都以 JSON 格式描述。

**示例 ABI 条目**:
```json
{
  "type": "function",
  "name": "swap",
  "inputs": [
    {"name": "tokenIn", "type": "address"},
    {"name": "amountIn", "type": "uint256"}
  ],
  "outputs": [
    {"name": "amountOut", "type": "uint256"}
  ],
  "stateMutability": "nonpayable"
}
```

### 方法 1: 从 Foundry 构建产物提取

```bash
# 导航到 foundry-demo
cd ../foundry-demo

# 构建合约
forge build

# 使用 jq 提取 ABI
jq '.abi' out/Swap.sol/Swap.json > ../web3-dapp/lib/abis/swap-raw.json

# 转换为 JavaScript 导出
cat > ../web3-dapp/lib/abis/swap.js <<EOF
export const SWAP_ABI = $(cat out/Swap.sol/Swap.json | jq '.abi')
EOF
```

### 方法 2: 使用 forge inspect

```bash
# 直接获取 ABI
forge inspect Swap abi > swap-abi.json

# 美化打印
forge inspect Swap abi --pretty
```

### 方法 3: 自动化脚本

创建 `foundry-demo/export-abis.sh`:

```bash
#!/bin/bash

CONTRACTS=("Swap" "StakePool" "Farm" "LaunchPad" "MemeFactory")
OUTPUT_DIR="../web3-dapp/lib/abis"

for contract in "${CONTRACTS[@]}"; do
  echo "导出 $contract ABI..."

  # 提取 ABI
  abi=$(jq '.abi' out/$contract.sol/$contract.json)

  # 创建 JS 文件
  cat > "$OUTPUT_DIR/${contract,,}.js" <<EOF
export const ${contract^^}_ABI = $abi
EOF
done

echo "所有 ABI 导出成功！"
```

运行:
```bash
chmod +x export-abis.sh
./export-abis.sh
```

### 在组件中使用 ABI

```javascript
import { useReadContract, useWriteContract } from 'wagmi'
import { SWAP_ABI } from '@/lib/abis/swap'

// 读取合约数据
const { data: reserves } = useReadContract({
  address: swapAddress,
  abi: SWAP_ABI,
  functionName: 'getReserves'
})

// 写入合约
const { writeContract } = useWriteContract()

await writeContract({
  address: swapAddress,
  abi: SWAP_ABI,
  functionName: 'swap',
  args: [tokenInAddress, amountIn]
})
```

## 🔗 合约集成模式

### 模式 1: 读取合约状态

```javascript
import { useReadContract } from 'wagmi'
import { formatUnits } from 'viem'

function TokenBalance({ address, tokenAddress }) {
  const { data: balance } = useReadContract({
    address: tokenAddress,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: [address],
    watch: true // 在区块变化时重新获取
  })

  return (
    <div>
      余额: {formatUnits(balance || 0n, 18)} 代币
    </div>
  )
}
```

### 模式 2: 带授权的合约写入

```javascript
import ApproveButton from '@/components/ApproveButton'
import { useWriteContract } from 'wagmi'
import { parseUnits } from 'viem'

function StakeTokens({ tokenAddress, poolAddress, amount }) {
  const { writeContract, isPending } = useWriteContract()

  const handleStake = async () => {
    await writeContract({
      address: poolAddress,
      abi: STAKE_POOL_ABI,
      functionName: 'stake',
      args: [parseUnits(amount, 18)]
    })
  }

  return (
    <div>
      {/* 首先授权代币 */}
      <ApproveButton
        tokenAddress={tokenAddress}
        spenderAddress={poolAddress}
        amount={amount}
        onSuccess={() => console.log('已授权!')}
      />

      {/* 然后质押 */}
      <button onClick={handleStake} disabled={isPending}>
        {isPending ? '质押中...' : '质押代币'}
      </button>
    </div>
  )
}
```

### 模式 3: 多步交易流程

```javascript
function AddLiquidity() {
  const [step, setStep] = useState(1) // 1=授权 A, 2=授权 B, 3=添加流动性

  const approveTokenA = async () => {
    await writeContract({
      address: tokenAAddress,
      abi: ERC20_ABI,
      functionName: 'approve',
      args: [swapAddress, parseUnits(amountA, 18)]
    })
    setStep(2)
  }

  const approveTokenB = async () => {
    await writeContract({
      address: tokenBAddress,
      abi: ERC20_ABI,
      functionName: 'approve',
      args: [swapAddress, parseUnits(amountB, 18)]
    })
    setStep(3)
  }

  const addLiquidity = async () => {
    await writeContract({
      address: swapAddress,
      abi: SWAP_ABI,
      functionName: 'addLiquidity',
      args: [parseUnits(amountA, 18), parseUnits(amountB, 18)]
    })
    setStep(1) // 重置
  }

  return (
    <div>
      {step === 1 && <button onClick={approveTokenA}>1. 授权代币 A</button>}
      {step === 2 && <button onClick={approveTokenB}>2. 授权代币 B</button>}
      {step === 3 && <button onClick={addLiquidity}>3. 添加流动性</button>}
    </div>
  )
}
```

## 🧩 组件复用

### 可复用的 ApproveButton 组件

`ApproveButton` 组件在 Pool、Farm 和 Swap 页面中使用:

```javascript
// components/ApproveButton.js（简化版）
import { useWriteContract } from 'wagmi'
import { ERC20_ABI } from '@/lib/abis/erc20'

export default function ApproveButton({
  tokenAddress,
  spenderAddress,
  amount,
  onSuccess
}) {
  const { writeContract, isPending } = useWriteContract()

  const handleApprove = async () => {
    await writeContract({
      address: tokenAddress,
      abi: ERC20_ABI,
      functionName: 'approve',
      args: [spenderAddress, parseUnits(amount, 18)]
    })
    onSuccess?.()
  }

  return (
    <button onClick={handleApprove} disabled={isPending}>
      {isPending ? '授权中...' : '授权'}
    </button>
  )
}
```

**使用示例**:
```javascript
<ApproveButton
  tokenAddress={process.env.NEXT_PUBLIC_TOKEN_A_ADDRESS}
  spenderAddress={process.env.NEXT_PUBLIC_SWAP_ADDRESS}
  amount="100"
  onSuccess={() => toast.success('已授权!')}
/>
```

## 🚀 部署

### 部署到 Vercel（推荐）

#### 选项 1: Vercel Dashboard

1. **导入项目**
   - 访问 [Vercel Dashboard](https://vercel.com/new)
   - 连接你的 Git 仓库
   - 选择仓库

2. **配置构建设置**
   - Framework Preset: **Next.js**（自动检测）
   - Root Directory: `./web3-dapp`（如果在 monorepo 中，否则留为 `/`）
   - Build Command: `npm run build`（自动检测）
   - Output Directory: `.next`（自动检测）

3. **添加环境变量**

   进入 "Environment Variables" 并添加:
   ```
   NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=your_project_id
   NEXT_PUBLIC_SWAP_ADDRESS=0x6bc3531769f05ea1b99a92c8fb5eb557c3715801
   NEXT_PUBLIC_STAKE_POOL_ADDRESS=0x1ad9af9efd7506666200b0748ce9761adf981417
   NEXT_PUBLIC_FARM_ADDRESS=0x55cdf982652a9cbca0a738443d3b3ec73f6e2989
   # ... 添加所有合约地址
   ```

4. **部署**
   - 点击 "Deploy"
   - 等待 2-3 分钟构建
   - 你的应用将在 `https://your-project.vercel.app` 上线

#### 选项 2: Vercel CLI

```bash
# 安装 Vercel CLI
npm i -g vercel

# 登录
vercel login

# 部署预览
vercel

# 部署生产
vercel --prod
```

## 🐛 故障排除

### 构建问题

**问题**: `Module not found: Can't resolve '@/components/...'`

**解决方案**: 确保 `jsconfig.json` 或 `tsconfig.json` 有路径映射:
```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["./*"]
    }
  }
}
```

### 钱包连接问题

**问题**: RainbowKit 无法连接或显示空白模态框

**解决方案**:
1. 确保设置了 `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID`
2. 检查 `lib/wagmiClient.js` 配置
3. 尝试清除浏览器缓存和 localStorage
4. 检查浏览器控制台是否有特定错误

### 合约交互错误

**问题**: 交易失败，出现 "execution reverted" 错误

**原因和解决方案**:

1. **Gas 不足**:
   ```javascript
   await writeContract({
     // ... 合约参数
     gas: 500000n // 手动设置 gas 限制
   })
   ```

2. **网络错误**:
   ```javascript
   import { useAccount, useSwitchChain } from 'wagmi'

   const { chain } = useAccount()
   const { switchChain } = useSwitchChain()

   if (chain?.id !== 11155111) { // Sepolia
     await switchChain({ chainId: 11155111 })
   }
   ```

3. **缺少代币授权**:
   - 始终在转账前检查并授权代币
   - 使用 `ApproveButton` 组件或手动授权检查

### BigInt 序列化错误

**解决方案**: 将 BigInt 转换为字符串以进行 JSON 序列化:
```javascript
// ❌ 错误
const data = { amount: 1000000000000000000n }
JSON.stringify(data) // 错误!

// ✅ 正确
const data = { amount: 1000000000000000000n.toString() }
JSON.stringify(data) // OK
```

## 📚 关键实现概念

### BigInt 处理

所有代币数量使用 `BigInt` 以保证精度:

```javascript
import { parseUnits, formatUnits } from 'viem'

// 用户输入 → Wei (BigInt)
const amountWei = parseUnits('1.5', 18) // 1500000000000000000n

// Wei → 显示 (string)
const displayAmount = formatUnits(1500000000000000000n, 18) // "1.5"

// 计算
const total = amountWei + parseUnits('0.5', 18) // 2000000000000000000n
```

### React Hooks for Web3

**关键 wagmi hooks**:

```javascript
import {
  useAccount,        // 获取连接的钱包地址
  useBalance,        // 获取 ETH/代币余额
  useReadContract,   // 读取合约数据
  useWriteContract,  // 写入合约
  useWaitForTransactionReceipt, // 等待交易确认
  useSwitchChain     // 切换网络
} from 'wagmi'

// 使用示例
const { address, isConnected } = useAccount()
const { data: balance } = useBalance({ address })
const { writeContract } = useWriteContract()
```

## 📖 其他资源

- **Next.js Docs**: https://nextjs.org/docs
- **wagmi Docs**: https://wagmi.sh/
- **viem Docs**: https://viem.sh/
- **RainbowKit Docs**: https://www.rainbowkit.com/docs/introduction
- **Tailwind CSS**: https://tailwindcss.com/docs
- **shadcn/ui**: https://ui.shadcn.com/
- **ECharts**: https://echarts.apache.org/en/index.html

## 📄 许可证

MIT License - 免费用于教育目的。

## 🌉 CCIP 跨链桥详细说明

### 概述

Bridge 模块使用 **Chainlink CCIP** (Cross-Chain Interoperability Protocol) 实现 **Sepolia ↔ Base Sepolia** 双向跨链。

### 核心机制

**Burn-Mint 模型**:
- **源链**: Burn (销毁) CCT Token
- **目标链**: Mint (铸造) CCT Token
- **总供应量**: 保持恒定（burn 和 mint 数量相等）

### 已部署合约

#### Sepolia 测试网
| 合约 | 地址 |
|------|------|
| CrossChainToken (CCT) | `0xDC1D17004a2A724d5aa9f6B428C56814aBD156D9` |
| CCIP Router | `0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59` |
| Chain Selector | `16015286601757825753` |

#### Base Sepolia 测试网
| 合约 | 地址 |
|------|------|
| CrossChainToken (CCT) | `0x431306040c181E768C4301a7bfD4fC6a770E833F` |
| CCIP Router | `0xD3b06cEbF099CE7DA4AcCf578aaebFDBd6e88a93` |
| Chain Selector | `10344971235874465080` |

### 前端集成步骤

#### 1. 环境变量配置

在 `.env.local` 中添加 CCIP 相关配置:

```bash
# CCIP 跨链桥合约地址
NEXT_PUBLIC_CCIP_TOKEN_SEPOLIA=0xDC1D17004a2A724d5aa9f6B428C56814aBD156D9
NEXT_PUBLIC_CCIP_TOKEN_BASE_SEPOLIA=0x431306040c181E768C4301a7bfD4fC6a770E833F
NEXT_PUBLIC_CCIP_ROUTER_SEPOLIA=0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59
NEXT_PUBLIC_CCIP_ROUTER_BASE_SEPOLIA=0xD3b06cEbF099CE7DA4AcCf578aaebFDBd6e88a93
NEXT_PUBLIC_CHAIN_SELECTOR_SEPOLIA=16015286601757825753
NEXT_PUBLIC_CHAIN_SELECTOR_BASE_SEPOLIA=10344971235874465080
```

#### 2. ABI 文件

**位置**: `/lib/abis/ccip/`

- `BurnMintERC20.json` - CCT Token 合约 ABI
- `IRouterClient.json` - CCIP Router 合约 ABI

这些 ABI 文件已从 Foundry 项目编译产物中提取。

#### 3. Bridge 页面实现

**文件**: `/app/bridge/page.js`

**核心功能**:
```javascript
import BurnMintERC20ABI from '@/lib/abis/ccip/BurnMintERC20.json'
import IRouterClientABI from '@/lib/abis/ccip/IRouterClient.json'

// 1. 读取余额
const { data: balance } = useReadContract({
  address: tokenAddress,
  abi: BurnMintERC20ABI,
  functionName: 'balanceOf',
  args: [userAddress],
  chainId: chainId
})

// 2. 授权代币
const { writeContract: writeApprove } = useWriteContract()
await writeApprove({
  address: tokenAddress,
  abi: BurnMintERC20ABI,
  functionName: 'approve',
  args: [routerAddress, amount]
})

// 3. 发起跨链
const message = {
  receiver: encodePacked(['address'], [recipientAddress]),
  data: '0x',
  tokenAmounts: [{ token: tokenAddress, amount: amount }],
  feeToken: '0x0000000000000000000000000000000000000000', // 使用 ETH 支付
  extraArgs: CCIP_EXTRA_ARGS
}

await writeBridge({
  address: routerAddress,
  abi: IRouterClientABI,
  functionName: 'ccipSend',
  args: [destinationChainSelector, message],
  value: estimatedFee // ~0.01 ETH
})
```

### 用户操作流程

#### 步骤 1: 连接钱包
- 确保钱包连接到 Sepolia 或 Base Sepolia
- 确认账户有足够的 ETH 支付 Gas 费用

#### 步骤 2: 查看余额
- 自动显示源链和目标链的 CCT 余额
- 实时刷新余额数据

#### 步骤 3: 输入转账金额
- 输入要跨链的 CCT 数量
- 可点击"最大"按钮使用全部余额

#### 步骤 4: 授权（首次需要）
- 如果首次跨链或授权额度不足，需先授权
- 点击"授权 X CCT"按钮
- 在钱包中确认授权交易
- 等待授权交易确认

#### 步骤 5: 发起跨链
- 授权完成后，点击"发起跨链"按钮
- 在钱包中确认跨链交易（需支付 ~0.0003 ETH）
- 等待交易确认

#### 步骤 6: 追踪跨链状态
- 交易确认后，会显示 CCIP Message ID
- 点击"在 CCIP Explorer 查看"可实时追踪跨链进度
- 跨链通常需要 5-15 分钟完成
- 完成后目标链余额会自动更新

### 替换指南：如何使用自己的跨链桥

如果您想替换成自己的跨链桥实现（如 LayerZero、Wormhole 或自定义桥），请按以下步骤操作:

#### 方法 1: 替换 CCIP 为 LayerZero

**步骤 1**: 在 `foundry-demo/` 中部署 LayerZero 合约

```solidity
// src/LayerZeroBridge.sol
import "@layerzerolabs/solidity-examples/contracts/token/oft/OFT.sol";

contract MyOFT is OFT {
    constructor(address _lzEndpoint) OFT("My Token", "MTK", _lzEndpoint) {}
}
```

**步骤 2**: 提取 LayerZero ABI

```bash
cd foundry-demo
forge build
jq '.abi' out/MyOFT.sol/MyOFT.json > ../web3-dapp/lib/abis/layerzero/MyOFT.json
```

**步骤 3**: 更新 `/app/bridge/page.js`

```javascript
import MyOFTABI from '@/lib/abis/layerzero/MyOFT.json'

// 替换跨链函数
const handleBridge = async () => {
  // LayerZero 跨链逻辑
  await writeContract({
    address: oftAddress,
    abi: MyOFTABI,
    functionName: 'sendFrom',
    args: [
      userAddress,        // from
      destChainId,        // destination LZ chain ID
      recipientAddress,   // to
      amount,             // amount
      refundAddress,      // refund address
      zeroAddress,        // zro payment address
      adapterParams       // adapter params
    ],
    value: nativeFee
  })
}
```

**步骤 4**: 更新环境变量

```bash
# .env.local
NEXT_PUBLIC_OFT_ADDRESS_SEPOLIA=0x...
NEXT_PUBLIC_OFT_ADDRESS_BASE=0x...
NEXT_PUBLIC_LZ_ENDPOINT_SEPOLIA=0x...
NEXT_PUBLIC_LZ_ENDPOINT_BASE=0x...
```

#### 方法 2: 添加更多支持的链

**步骤 1**: 在 `foundry-demo/` 部署到新链（如 Arbitrum Sepolia）

```bash
forge script script/ccip/DeployToken.s.sol \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

**步骤 2**: 更新 `SUPPORTED_CHAINS` 常量

```javascript
// app/bridge/page.js
const SUPPORTED_CHAINS = [
  {
    id: 11155111,
    name: 'Sepolia',
    tokenAddress: process.env.NEXT_PUBLIC_CCIP_TOKEN_SEPOLIA,
    routerAddress: process.env.NEXT_PUBLIC_CCIP_ROUTER_SEPOLIA,
    chainSelector: process.env.NEXT_PUBLIC_CHAIN_SELECTOR_SEPOLIA
  },
  {
    id: 84532,
    name: 'Base Sepolia',
    tokenAddress: process.env.NEXT_PUBLIC_CCIP_TOKEN_BASE_SEPOLIA,
    routerAddress: process.env.NEXT_PUBLIC_CCIP_ROUTER_BASE_SEPOLIA,
    chainSelector: process.env.NEXT_PUBLIC_CHAIN_SELECTOR_BASE_SEPOLIA
  },
  // 新增 Arbitrum Sepolia
  {
    id: 421614,
    name: 'Arbitrum Sepolia',
    tokenAddress: process.env.NEXT_PUBLIC_CCIP_TOKEN_ARB_SEPOLIA,
    routerAddress: process.env.NEXT_PUBLIC_CCIP_ROUTER_ARB_SEPOLIA,
    chainSelector: process.env.NEXT_PUBLIC_CHAIN_SELECTOR_ARB_SEPOLIA
  }
]
```

**步骤 3**: 添加新环境变量

```bash
NEXT_PUBLIC_CCIP_TOKEN_ARB_SEPOLIA=0x...
NEXT_PUBLIC_CCIP_ROUTER_ARB_SEPOLIA=0x...
NEXT_PUBLIC_CHAIN_SELECTOR_ARB_SEPOLIA=...
```

#### 方法 3: 自定义 Bridge UI

**步骤 1**: 复制 Bridge 页面

```bash
cp app/bridge/page.js app/my-bridge/page.js
```

**步骤 2**: 自定义 UI 组件

```javascript
// app/my-bridge/page.js
export default function MyBridgePage() {
  // 保留核心跨链逻辑
  const handleBridge = async () => { /* CCIP 逻辑 */ }

  return (
    <div className="my-custom-design">
      {/* 你的自定义 UI */}
      <MyCustomForm onSubmit={handleBridge} />
      <MyCustomHistory transfers={transfers} />
    </div>
  )
}
```

**步骤 3**: 更新导航链接

```javascript
// components/Navbar.js
{ name: 'Bridge', href: '/my-bridge' }
```

### 费用说明

| 操作 | Gas 费用 (Sepolia) | CCIP 费用 | 总计 |
|------|-------------------|-----------|------|
| 授权 CCT | ~0.00002 ETH | - | ~0.00002 ETH |
| 发起跨链 | ~0.0001 ETH | ~0.0002 ETH | ~0.0003 ETH |

**注意**:
- 费用会根据网络拥堵情况波动
- 前端预估费用为 0.01 ETH，实际费用约 0.0003 ETH，多余部分不退还
- 建议账户至少准备 0.5 ETH 测试币

### 测试网水龙头

获取测试网 ETH 和 CCT 代币:

**Sepolia ETH**:
- https://sepoliafaucet.com/
- https://www.alchemy.com/faucets/ethereum-sepolia

**Base Sepolia ETH**:
- https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet
- https://docs.base.org/tools/network-faucets/

**CCT Token**:
- 在 Sepolia 上有 1000 CCT 可用于测试
- 使用 Bridge 从 Sepolia 跨到 Base Sepolia

### 故障排查

#### 问题 1: 跨链卡住，长时间未完成

**可能原因**:
- CCIP 网络拥堵
- Gas 费用不足
- 目标链 RPC 问题

**解决方案**:
1. 访问 [CCIP Explorer](https://ccip.chain.link/) 查看 Message ID 状态
2. 等待 15-20 分钟后再次检查
3. 检查 [Chainlink Status](https://status.chain.link/) 确认 CCIP 服务正常

#### 问题 2: 授权失败

**可能原因**:
- 钱包网络不匹配
- Gas 费用不足
- Token 地址错误

**解决方案**:
1. 确认钱包连接到正确的网络（Sepolia 或 Base Sepolia）
2. 检查账户 ETH 余额是否充足
3. 点击"切换到 XXX"按钮自动切换网络

#### 问题 3: 跨链交易 revert

**可能原因**:
- 授权额度不足
- CCT 余额不足
- CCIP Router 地址错误
- 目标链不支持

**解决方案**:
1. 确认已授权足够的 CCT 给 Router
2. 检查 CCT 余额是否大于转账金额
3. 验证 `.env` 中的 Router 地址是否正确
4. 确认目标链在支持列表中

### 参考资源

- **Chainlink CCIP 文档**: https://docs.chain.link/ccip
- **CCIP Explorer**: https://ccip.chain.link/
- **支持的网络**: https://docs.chain.link/ccip/supported-networks
- **Burn-Mint Token 标准**: https://docs.chain.link/ccip/tutorials/cross-chain-tokens
- **Foundry CCIP 部署指南**: 查看 `../foundry-demo/README.md` 的 CCIP 模块章节

## 🤝 贡献

这是一个旨在高度可替换的教育项目。欢迎:
- 用你自己的实现替换任何页面
- 添加新的 DeFi 模块（期权、永续合约、借贷等）
- 修改合约集成逻辑
- 尝试不同的 UI 库
- 添加新的区块链网络
- 集成其他跨链协议（LayerZero、Wormhole 等）

所有代码都有良好的注释，结构清晰，便于学习。
