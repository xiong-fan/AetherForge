# Chainlink CCIP Burn & Mint 跨链代币部署前戏完整流程

## 概述
在执行跨链转移之前，必须完成一系列准备工作（俗称“前戏”），让你的 ERC20 代币成为支持 CCIP 的 **Cross-Chain Token (CCT)**。  
整个流程需要在**源链和目标链上分别执行**部分步骤。

## 完整执行顺序（严格遵守）

### 1. DeployToken —— 部署跨链代币本体
- **脚本**：`DeployToken.s.sol`
- **核心操作**：
  - 部署 `BurnMintERC20` 合约（Chainlink 官方提供的可 mint/burn 的 ERC20）
  - 给部署者授予 `MINTER_ROLE` 和 `BURNER_ROLE`
- **输出**：`output/deployedToken_[chainName].json`
- **目的**：创建支持 Burn/Mint 的原生代币
- **要求**：需要在**源链和目标链上各部署一次**

### 2. DeployBurnMintTokenPool —— 部署 Token Pool
- **脚本**：`DeployBurnMintTokenPool.s.sol`
- **核心操作**：
  - 部署 `BurnMintTokenPool` 合约
  - 将 mint/burn 权限授予该 Pool
- **输出**：`output/deployedTokenPool_[chainName].json`
- **目的**：创建负责跨链 Burn（源链销毁）和 Mint（目标链铸造）的专用池
- **要求**：同样需要在**每条链上各部署一次**

### 3. ClaimAdmin —— 声明管理员权限（第一步）
- **脚本**：`ClaimAdmin.s.sol`
- **核心操作**：
  - 调用 `RegistryModuleOwnerCustom.registerAdminViaGetCCIPAdmin(tokenAddress)`
  - 内部检查 `token.getCCIPAdmin()` 是否等于当前调用者
- **目的**：向 `TokenAdminRegistry` 声明“我是这个 Token 的管理员”，将其设置为 `pendingAdministrator`
- **要求**：每条链上都需要执行

### 4. AcceptAdminRole —— 正式接受管理员权限（第二步）
- **脚本**：`AcceptAdminRole.s.sol`
- **核心操作**：
  - 调用 `TokenAdminRegistry.acceptAdminRole(tokenAddress)`
  - 检查调用者是否为上一步的 `pendingAdministrator`
- **目的**：完成管理员权限确认，成为 `TokenAdminRegistry` 中的正式 `administrator`
- **要求**：每条链上都需要执行

### 5. SetPool —— 绑定 Token 与 Pool
- **脚本**：`SetPool.s.sol`
- **核心操作**：
  - 调用 `TokenAdminRegistry.setPool(tokenAddress, poolAddress)`
- **目的**：将 Token 和对应的 BurnMintTokenPool 正式绑定
- **要求**：每条链上都需要执行
- **关键**：必须在 Claim + Accept 完成后才能执行

### 6. ApplyChainUpdates —— 配置跨链映射（最核心步骤）
- **脚本**：`ApplyChainUpdates.s.sol`
- **核心操作**：
  - 在源链 Pool 上调用 `applyChainUpdates`，传入目标链的 `chainSelector`、目标 Pool 地址、目标 Token 地址
  - 在目标链 Pool 上反向执行一次
- **目的**：让两条链的 Pool 互相认识，建立双向 Burn-Mint 通道
- **要求**：双向配置，必须在 SetPool 完成后执行

## 流程总结（推荐执行顺序）

1. DeployToken（源链 + 目标链）
2. DeployBurnMintTokenPool（源链 + 目标链）
3. ClaimAdmin（源链 + 目标链）
4. AcceptAdminRole（源链 + 目标链）
5. SetPool（源链 + 目标链）
6. ApplyChainUpdates（双向配置）

完成以上 6 个步骤后，你的代币才真正成为支持 CCIP 的 **Cross-Chain Token**，可以安全地使用 `tokenAmounts` 进行跨链转移。

## 重要注意事项

- **顺序不可颠倒**：尤其是 Claim → Accept → SetPool → ApplyChainUpdates 必须严格按顺序执行
- **每条链都要执行**：前 5 步需要在源链和目标链上分别跑一次
- **ApplyChainUpdates 是双向的**：源链要配置目标链，目标链也要配置源链
- **生产环境建议**：使用多签钱包（Gnosis Safe）执行 Claim、Accept、SetPool 等关键权限操作
- **测试网推荐**：先在 Sepolia + Base Sepolia 之间跑通整个流程

## 为什么需要这些前戏？

- 让普通 ERC20 变成 CCIP 认可的 **Cross-Chain Token**
- 通过 TokenAdminRegistry 完成安全注册和权限管理
- 建立源链与目标链 Pool 之间的信任关系
- 确保跨链时的 Burn（源链）和 Mint（目标链）由官方 Pool 安全执行