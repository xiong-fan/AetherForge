# Chainlink CCIP Burn & Mint 跨链转账完整合约交互流程

（以 **BurnMintTokenPool** 为例，纯 Token 转移为主，EVM 链）

## 前置条件（必须完成，否则流程无法启动）

- 代币已在 **TokenAdminRegistry** 正确注册（两步：propose + accept admin role）。
- 在源链和目标链都部署 **BurnMintTokenPool** 并通过 `setPool(token, poolAddress)` 关联。
- 池子已调用 `applyChainUpdates` 配置目标链（包括 rate limit、remote pool 等）。
- 用户已 approve 足够代币给 Router（或池子，根据实现）。
- **核心注意**：TokenAdminRegistry 是整个流程的“路由表”，Router/OnRamp/OffRamp 都通过它查询你的池子地址。如果未 setPool，后续所有 token 操作都会失败。

## 完整跨链交互流程（函数调用序列）

### 第一阶段：源链（Source Chain） - 发起跨链

**第 1 步：用户/合约发起请求**  
- **调用者**：用户（EOA）或你的合约  
- **调用合约**：**Router**  
- **函数**：`Router.ccipSend(uint64 destinationChainSelector, Client.EVM2AnyMessage calldata message)`  
- **特别注意**：  
  - 这是**唯一统一入口**，必须走 Router。  
  - message 中包含 `tokenAmounts`（token 地址 + amount）、`receiver`、`data`（可选）、`feeToken` 等。  
  - Router 先计算并收取费用（getFee），用户支付 LINK 或原生 token。  
  - 如果费用不足或 approve 不够，直接 revert。

**第 2 步：Router 处理并转发**  
- **调用合约**：**Router** → **OnRamp**（源链对应的 OnRamp，由 Router 配置）  
- Router 内部通过 **TokenAdminRegistry** 查询 token 对应的 **BurnMintTokenPool** 地址。  
- Router 把 token 转移逻辑转发给 OnRamp。

**第 3 步：OnRamp 处理 token 操作**  
- **调用合约**：**OnRamp** → **BurnMintTokenPool**  
- **函数**：`BurnMintTokenPool.lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn)`  
- **特别注意**：OnRamp 是源链的“打包器”，负责 nonce、消息构建。

**第 4 步：池子执行 burn（核心 token 操作）**  
- **调用合约**：**BurnMintTokenPool**（继承 TokenPool + BurnMintTokenPoolAbstract）  
- 内部流程：  
  1. 调用 `TokenPool._validateLockOrBurn()`（关键安全校验）  
     - 检查调用者是否为合法 OnRamp（通过 Router 配置）。  
     - 检查 RMN（Risk Management Network）是否 curse 该 lane（暂停保护）。  
     - 检查 rate limiter（速率限制，防大额攻击）。  
     - 检查 allowlist（如果开启）。  
     - 检查 remote chain 配置。  
  2. 通过校验后，调用内部 `_burn(amount)` → `YourToken.burn(amount)`（销毁代币）。  
  3. 发出 `Burned` / `LockedOrBurned` 事件。  
  4. 返回目标链所需数据（destTokenAddress + poolData 用于 decimals 处理）。  

**第 5 步：OnRamp 完成消息打包**  
- OnRamp 生成唯一 `messageId`，发出 `CCIPSendRequested` 或类似事件。  
- 消息进入 Chainlink offchain DON（Committing DON），不在 onchain 调用范围内。

**源链结束**：代币已被 burn，消息已发出到 CCIP 网络。

### 第二阶段：目标链（Destination Chain） - 执行跨链

**第 6 步：Executing DON 执行消息**  
- **调用者**：Chainlink **Executing DON**（offchain 节点网络）  
- **调用合约**：**OffRamp**（目标链对应的 OffRamp，由 Router 配置）  
- **函数**：`OffRamp.execute(...)`（或批量执行函数，携带 Merkle proof、report 等）  
- **特别注意**：  
  - 这不是用户直接调用，而是 Chainlink DON 驱动。  
  - OffRamp 不需要经过 Router 才能调用 releaseOrMint（这就是目标链 Router 不直接参与的原因）。  
  - 执行前会做多重验证：Merkle proof、RMN blessing、nonce 防重放、source chain 未 curse 等。

**第 7 步：OffRamp 处理 token 操作**  
- **调用合约**：**OffRamp** → 通过 **TokenAdminRegistry** 获取 **BurnMintTokenPool** 地址  
- **函数**：`BurnMintTokenPool.releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn)`  

**第 8 步：池子执行 mint（核心 token 操作）**  
- **调用合约**：**BurnMintTokenPool**  
- 内部流程：  
  1. 调用 `TokenPool._validateReleaseOrMint()`（类似源链的安全校验）  
     - 检查调用者是否为合法 OffRamp。  
     - RMN、rate limiter、remote pool 配置等。  
  2. 计算本地金额（`_calculateLocalAmount`，处理 decimals 差异）。  
  3. 调用 `YourToken.mint(receiver, localAmount)`（铸造代币给 receiver）。  
  4. 发出 `Minted` / `ReleasedOrMinted` 事件。  

**第 9 步：可选 - 处理带 data 的消息**  
- 如果 message 中 `data` 不为空（且 gasLimit > 0）：  
  - **OffRamp** → **Router.routeMessage(...)**  
  - **Router** → `receiver.ccipReceive(Any2EVMMessage calldata)`（receiver 必须是合约并实现该函数）。  
- **纯 Token 转移**（data = 0x）：这一步完全跳过，Router 不参与。

**目标链结束**：接收者收到 mint 的代币，消息标记为已执行。

## 流程总结表（核心调用链）

| 阶段       | 调用顺序                                      | 主要合约交互                              | Router 参与情况          | 备注 |
|------------|-----------------------------------------------|-------------------------------------------|--------------------------|------|
| 源链发起   | User → Router → OnRamp → BurnMintTokenPool   | ccipSend → lockOrBurn                     | 是（入口）              | 必须走 Router |
| 源链 token | OnRamp → BurnMintTokenPool → YourToken       | lockOrBurn → _validate → burn             | 间接                    | burn 代币 |
| 目标链执行 | DON → OffRamp → BurnMintTokenPool            | execute → releaseOrMint                   | 否（纯 token 时）       | DON 直接调用 |
| 目标链 token | OffRamp → BurnMintTokenPool → YourToken     | releaseOrMint → _validate → mint          | 否                      | mint 代币 |
| 目标链投递 | OffRamp → Router → Receiver（可选）          | routeMessage → ccipReceive                | 是（仅带 data 时）      | 可编程转账 |

## 额外核心说明
- **TokenAdminRegistry**：全程被 Router、OnRamp、OffRamp 查询池子地址，是注册流程存在的根本原因。
- **RMNProxy**：在 validate 函数中被调用，提供 curse/blessing 安全机制。
- **RateLimiter**：在 TokenPool 中限制单笔/时间段最大跨链量。
- **纯 token vs 带 data**：纯 token 最省 gas，Router 只在源链参与；带 data 时目标链 Router 负责最后投递。

此流程基于 Chainlink 官方文档（v1.5+ / v1.6）及合约逻辑。如果你需要添加序列图描述、某个具体函数的代码片段、或常见失败点分析，告诉我我可以继续补充。