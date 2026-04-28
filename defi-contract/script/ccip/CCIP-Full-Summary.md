# Chainlink CCIP 学习总结（昨天晚上 + 今天凌晨问答全集）

## 一、整体架构与核心概念

### 1. ccipSend 跨链消息发送流程
当调用 `router.ccipSend(destinationChainSelector, message)` 时：
- 源链：Router → OnRamp → 发出事件日志
- 链下：Committing DON（链下节点）通过 RPC 主动轮询源链事件
- 验证：RMN 进行风险检查
- 目标链：Executing DON 调用 OffRamp → 处理 Token Pool → Router → Receiver（如果有 data）

**关键点**：区块链是被动的，跨链依靠链下 DON 节点主动读取日志并提交证明。

### 2. 两种跨链模式对比
- **Burn & Mint**（Learn-DeFi 项目）：
  - 源链 Burn（销毁），目标链 Mint（铸造）
  - 优点：资本效率高，总供应量一致
  - 需要完整 6 步前戏注册

- **Lock & Unlock**（NFTPoolLockAndRelease 示例）：
  - 源链手动 transferFrom 锁定资产
  - 目标链手动解锁或 mint wrapped 版本
  - 通常 `tokenAmounts` 为空，主要靠 `data` 传递指令

### 3. 重要组件对比
- **chainSelector**：一条链的唯一标识符（uint64），相当于区号
- **Router**：当前链上 CCIP 的入口合约，负责 ccipSend 和消息投递
- **CCIPReceiver**：接收消息的基础合约，用于实现 `_ccipReceive`
- **BurnMintTokenPool**：专门负责 ERC20 Burn/Mint 的官方池

---

## 二、Burn & Mint 前戏完整 6 步流程

1. **DeployToken**  
   部署 `BurnMintERC20`，授予 mint/burn 权限。每条链都要部署。

2. **DeployBurnMintTokenPool**  
   部署 Token Pool，并把 mint/burn 权限授予 Pool。每条链都要部署。

3. **ClaimAdmin**（第一步）  
   调用 `RegistryModuleOwnerCustom.registerAdminViaGetCCIPAdmin(tokenAddress)`  
   检查 `token.getCCIPAdmin()` 是否等于调用者 → 设置 pendingAdministrator。

4. **AcceptAdminRole**（第二步）  
   调用 `TokenAdminRegistry.acceptAdminRole(tokenAddress)`  
   检查调用者是否为 pendingAdministrator → 正式成为管理员。

5. **SetPool**  
   调用 `TokenAdminRegistry.setPool(tokenAddress, poolAddress)`  
   绑定 Token 与 Pool。

6. **ApplyChainUpdates**（最核心）  
   在源链和目标链的 Pool 上双向配置对方链的 Pool 地址和 Token 地址。

**注意**：前 5 步每条链都要执行，ApplyChainUpdates 必须双向配置。

---

## 三、Claim + Accept 两步确认机制

### getCCIPAdmin()
- 来自 `BurnMintERC20` 合约，是 `immutable` 变量
- 部署 Token 时自动设为部署者地址，部署后**永久不可修改**

### ClaimAdmin
- 检查当前 `getCCIPAdmin()` 是否等于调用者
- 作用：声明管理员，设置为 pendingAdministrator

### AcceptAdminRole
- 检查调用者是否为 pendingAdministrator
- 作用：正式接受管理员权限

**为什么需要两步？**
- 防止别人抢先 Claim
- 支持多签、DAO、团队管理
- 便于后续管理员权限转移

---

## 四、tokenAmounts 与 data 的核心区别

- **`tokenAmounts`**：
  - CCIP 专门用于转移资产的字段
  - 只能放 `{token: address, amount: uint256}`
  - 必须是已完成完整前戏的“支持 CCIP 的 Token”

- **`data`**：
  - 自定义任意数据（bytes）
  - 用于传递指令（如 tokenId、newOwner、struct）
  - 在 `_ccipReceive` 中手动 decode

- **Programmable Token Transfer**：
  - 同时使用 tokenAmounts + data（两者都不为空）

### _ccipReceive 函数
- 可同时处理 `data`（指令）和 `destTokenAmounts`（自动到账的资产）
- 纯 tokenAmounts + data 为空时，通常不需要实现该函数（如果 receiver 是 EOA）

---

## 五、NFT 跨链示例关键点
- `tokenAmounts` 通常为空
- 通过 `data` 传递 `tokenId` 和 `newOwner`
- 源链手动锁定 NFT，目标链在 `_ccipReceive` 中手动 mint wrapped NFT
- 属于 Lock & Mint 模式

---

## 六、常见问题解答

1. **为什么每条链都要部署 Token？**  
   Burn & Mint 需要每条链都有自己的 Token + Pool，才能实现源链 Burn + 目标链 Mint。

2. **“支持 CCIP 的 Token”是什么意思？**  
   指完成了 6 步前戏注册的 Token。只有这样才能安全放入 `tokenAmounts`。

3. **Router → Receiver 什么时候执行？**  
   只有 `data` 不为空时才会完整调用 `_ccipReceive`。纯 Token 转移时通常不触发。

4. **管理员权限如何转移？**  
   当前管理员调用 `transferAdminRole(token, newAdmin)`，新地址再调用 `acceptAdminRole`。

5. **为什么不直接判断部署者？**  
   - 支持多签、DAO 等复杂场景
   - 支持后续权限转移
   - 提供安全缓冲

---

**复习重点**：
- 6 步前戏顺序
- Claim + Accept 两步原因
- tokenAmounts 与 data 的区别
- getCCIPAdmin() 是 immutable

---

