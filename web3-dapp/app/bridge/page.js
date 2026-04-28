'use client'

import { useState, useEffect } from 'react'
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt, useSwitchChain } from 'wagmi'
import { parseUnits, formatUnits } from '@/lib/utils/units'
import { encodePacked, encodeAbiParameters, keccak256, toHex } from 'viem'
import BurnMintERC20ABI from '@/lib/abis/ccip/BurnMintERC20.json'
import IRouterClientABI from '@/lib/abis/ccip/IRouterClient.json'

/**
 * Bridge 页面（CCIP跨链桥）
 *
 * 功能：
 * - Sepolia ↔ Base Sepolia 双向跨链
 * - 使用 Chainlink CCIP 协议
 * - 支持 CCT (CrossChainToken) 跨链转账
 * - 实时余额查询
 * - 跨链进度追踪
 */

const SUPPORTED_CHAINS = [
  {
    id: 11155111,
    name: 'Sepolia',
    symbol: 'SEP',
    tokenAddress: process.env.NEXT_PUBLIC_CCIP_TOKEN_SEPOLIA,
    routerAddress: process.env.NEXT_PUBLIC_CCIP_ROUTER_SEPOLIA,
    chainSelector: process.env.NEXT_PUBLIC_CHAIN_SELECTOR_SEPOLIA
  },
  {
    id: 84532,
    name: 'Base Sepolia',
    symbol: 'BASE',
    tokenAddress: process.env.NEXT_PUBLIC_CCIP_TOKEN_BASE_SEPOLIA,
    routerAddress: process.env.NEXT_PUBLIC_CCIP_ROUTER_BASE_SEPOLIA,
    chainSelector: process.env.NEXT_PUBLIC_CHAIN_SELECTOR_BASE_SEPOLIA
  }
]

// CCIP EVMExtraArgsV1 编码
// const CCIP_EXTRA_ARGS = encodePacked(
//   ['bytes4', 'bytes'],
//   [
//     keccak256(toHex('CCIP EVMExtraArgsV1')).slice(0, 10),
//     encodeAbiParameters([{ type: 'uint256' }], [BigInt(0)])
//   ]
// )

const CCIP_EXTRA_ARGS = encodeAbiParameters(
  [
    { type: 'bytes4' }, // tag
    {
      type: 'tuple',
      components: [
        { type: 'uint256', name: 'gasLimit' },
        { type: 'bool', name: 'strict' }
      ]
    }
  ],
  [
    '0x97a657c9',                    // EVMExtraArgsV1 的标准 tag
    { gasLimit: 0n, strict: false }  // 纯 token 转移建议 gasLimit = 0
  ]
);

// 跨链记录组件
function TransferRecord({ transfer, sourceChain, targetChain }) {
  const [countdown, setCountdown] = useState(900) // 15分钟倒计时

  useEffect(() => {
    if (transfer.status === 'complete') return

    const interval = setInterval(() => {
      setCountdown(prev => (prev > 0 ? prev - 1 : 0))
    }, 1000)

    return () => clearInterval(interval)
  }, [transfer.status])

  const getStatusInfo = (status) => {
    switch (status) {
      case 'pending':
        return { text: '等待确认', color: 'bg-yellow-100 text-yellow-800', icon: '⏳' }
      case 'confirmed':
        return { text: 'CCIP处理中', color: 'bg-blue-100 text-blue-800', icon: '🚀' }
      case 'complete':
        return { text: '已完成', color: 'bg-green-100 text-green-800', icon: '✓' }
      default:
        return { text: status, color: 'bg-gray-100 text-gray-800', icon: '?' }
    }
  }

  const statusInfo = getStatusInfo(transfer.status)
  const minutes = Math.floor(countdown / 60)
  const seconds = countdown % 60

  return (
    <div className="bg-white rounded-lg shadow p-4 mb-3">
      <div className="flex items-start justify-between mb-3">
        <div className="flex-1">
          <div className="flex items-center gap-2 mb-2">
            <span className={`px-3 py-1 rounded-full text-xs font-semibold ${statusInfo.color}`}>
              {statusInfo.icon} {statusInfo.text}
            </span>
            {transfer.status !== 'complete' && (
              <span className="text-xs text-gray-500">
                预计 {minutes}:{seconds.toString().padStart(2, '0')}
              </span>
            )}
          </div>
          <div className="text-sm text-gray-600">
            {sourceChain.name} → {targetChain.name}
          </div>
          <div className="text-lg font-semibold">
            {transfer.amount} CCT
          </div>
        </div>
      </div>

      {/* CCIP Message ID */}
      <div className="mt-2 text-xs text-gray-500">
        <div className="font-mono break-all">MessageID: {transfer.messageId || '等待生成...'}</div>
        {transfer.messageId && (
          <a
            href={`https://ccip.chain.link/#/side-drawer/msg/${transfer.messageId}`}
            target="_blank"
            rel="noopener noreferrer"
            className="text-blue-600 hover:underline mt-1 inline-block"
          >
            在 CCIP Explorer 查看 →
          </a>
        )}
      </div>

      {transfer.txHash && (
        <div className="mt-2 text-xs">
          <a
            href={`https://sepolia.etherscan.io/tx/${transfer.txHash}`}
            target="_blank"
            rel="noopener noreferrer"
            className="text-blue-600 hover:underline"
          >
            查看交易详情 →
          </a>
        </div>
      )}
    </div>
  )
}

export default function BridgePage() {
  const { address, isConnected, chain: currentChain } = useAccount()
  const { switchChain } = useSwitchChain()

  // 表单状态
  const [sourceChainId, setSourceChainId] = useState(11155111) // Sepolia
  const [amount, setAmount] = useState('')

  // 跨链状态
  const [isApproving, setIsApproving] = useState(false)
  const [isBridging, setIsBridging] = useState(false)
  const [error, setError] = useState(null)
  const [transfers, setTransfers] = useState([])

  const sourceChain = SUPPORTED_CHAINS.find(c => c.id === sourceChainId)
  const targetChain = SUPPORTED_CHAINS.find(c => c.id !== sourceChainId)

  // 读取源链余额
  const { data: sourceBalance, refetch: refetchSourceBalance } = useReadContract({
    address: sourceChain?.tokenAddress,
    abi: BurnMintERC20ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    chainId: sourceChainId,
    enabled: Boolean(address && sourceChain?.tokenAddress)
  })

  // 读取目标链余额
  const { data: targetBalance, refetch: refetchTargetBalance } = useReadContract({
    address: targetChain?.tokenAddress,
    abi: BurnMintERC20ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    chainId: targetChain?.id,
    enabled: Boolean(address && targetChain?.tokenAddress)
  })

  // 读取授权额度
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: sourceChain?.tokenAddress,
    abi: BurnMintERC20ABI,
    functionName: 'allowance',
    args: address && sourceChain ? [address, sourceChain.routerAddress] : undefined,
    chainId: sourceChainId,
    enabled: Boolean(address && sourceChain?.tokenAddress && sourceChain?.routerAddress)
  })

  const { writeContract: writeApprove, data: approveHash } = useWriteContract()
  const { writeContract: writeBridge, data: bridgeHash } = useWriteContract()

  const { isSuccess: approveSuccess } = useWaitForTransactionReceipt({ hash: approveHash })
  const { isSuccess: bridgeSuccess, data: bridgeReceipt } = useWaitForTransactionReceipt({ hash: bridgeHash })

  // 监听授权成功
  useEffect(() => {
    if (approveSuccess) {
      setIsApproving(false)
      refetchAllowance()
    }
  }, [approveSuccess, refetchAllowance])

  // 监听跨链交易成功
  useEffect(() => {
    if (bridgeSuccess && bridgeReceipt) {
      setIsBridging(false)

      // 从交易日志中提取 Message ID
      const ccipSendLog = bridgeReceipt.logs?.find(log =>
        log.topics[0] === keccak256(toHex('CCIPSendRequested((uint64,bytes,bytes,((address,uint256)[])),bytes32)'))
      )

      const messageId = ccipSendLog?.topics[1] || bridgeHash

      // 添加到转账记录
      setTransfers(prev => [{
        messageId,
        txHash: bridgeHash,
        amount: amount,
        status: 'confirmed',
        timestamp: Date.now()
      }, ...prev])

      // 清空表单
      setAmount('')

      // 刷新余额
      refetchSourceBalance()
      setTimeout(() => refetchTargetBalance(), 60000) // 1分钟后刷新目标链余额
    }
  }, [bridgeSuccess, bridgeReceipt, bridgeHash, amount, refetchSourceBalance, refetchTargetBalance])

  const userSourceBalance = sourceBalance ? formatUnits(sourceBalance, 18, 6) : '0'
  const userTargetBalance = targetBalance ? formatUnits(targetBalance, 18, 6) : '0'
  const currentAllowance = allowance ? BigInt(allowance.toString()) : BigInt(0)
  const amountWei = amount ? parseUnits(amount, 18) : BigInt(0)

  const needsApproval = amountWei > currentAllowance

  const handleSwitchChain = () => {
    if (switchChain) {
      switchChain({ chainId: sourceChainId })
    }
  }

  const handleApprove = async () => {
    if (!amount || parseFloat(amount) <= 0) {
      setError('请输入有效的转账数量')
      return
    }

    setError(null)
    setIsApproving(true)

    try {
      writeApprove({
        address: sourceChain.tokenAddress,
        abi: BurnMintERC20ABI,
        functionName: 'approve',
        args: [sourceChain.routerAddress, parseUnits(amount, 18)],
        chainId: sourceChainId
      })
    } catch (err) {
      console.error('授权失败:', err)
      setError('授权失败: ' + (err.message || '未知错误'))
      setIsApproving(false)
    }
  }

  const handleBridge = async () => {
    if (!amount || parseFloat(amount) <= 0) {
      setError('请输入有效的转账数量')
      return
    }

    if (!address) {
      setError('请先连接钱包')
      return
    }

    setError(null)
    setIsBridging(true)

    // try {
    //   // 构建 CCIP 消息
    //   const message = {
    //     receiver: encodePacked(['address'], [address]),
    //     data: '0x',
    //     tokenAmounts: [{
    //       token: sourceChain.tokenAddress,
    //       amount: parseUnits(amount, 18)
    //     }],
    //     feeToken: '0x0000000000000000000000000000000000000000', // 使用原生代币支付
    //     extraArgs: CCIP_EXTRA_ARGS
    //   }

    //   writeBridge({
    //     address: sourceChain.routerAddress,
    //     abi: IRouterClientABI,
    //     functionName: 'ccipSend',
    //     args: [BigInt(targetChain.chainSelector), message],
    //     value: parseUnits('0.01', 18), // 预估 0.01 ETH 作为费用
    //     chainId: sourceChainId
    //   })
    // } catch (err) {
    //   console.error('跨链失败:', err)
    //   setError('跨链失败: ' + (err.message || '未知错误'))
    //   setIsBridging(false)
    // }

    try {

      const message = {
        receiver: encodeAbiParameters(
          [{ type: 'address' }],
          [address]
        ),
        data: '0x',                          // 纯 token 转移保持为空
        tokenAmounts: [{
          token: sourceChain.tokenAddress,
          amount: parseUnits(amount, 18)
        }],
        feeToken: '0x0000000000000000000000000000000000000000', // 原生 ETH 支付费用
        extraArgs: CCIP_EXTRA_ARGS
      };

      writeBridge({
        address: sourceChain.routerAddress,
        abi: IRouterClientABI,
        functionName: 'ccipSend',
        args: [BigInt(targetChain.chainSelector), message],
        value: parseUnits('0.005', 18),   // 先给 0.005 ETH，后面再优化
        chainId: sourceChainId
      });
    } catch (err) {
      console.error('跨链失败:', err);
      setError('跨链失败: ' + (err.message || '未知错误'));
    }
  }

  const handleMaxAmount = () => {
    setAmount(userSourceBalance)
  }

  const handleSwitchDirection = () => {
    setSourceChainId(targetChain.id)
  }

  const isWrongNetwork = currentChain?.id !== sourceChainId

  return (
    <div className="container py-12">
      <div className="max-w-4xl mx-auto">
        {/* 页面头部 */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold mb-2">跨链桥 (CCIP)</h1>
          <p className="text-gray-600">使用 Chainlink CCIP 在 Sepolia 和 Base Sepolia 之间安全转移 CCT 代币</p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* 左侧：转账表单 */}
          <div className="bg-white rounded-lg shadow-lg p-6">
            <h2 className="text-xl font-bold mb-6">发起跨链转账</h2>

            {/* 余额显示 */}
            <div className="mb-6 p-4 bg-gray-50 rounded-lg">
              <div className="flex justify-between mb-2">
                <span className="text-sm text-gray-600">{sourceChain.name} 余额:</span>
                <span className="font-semibold">{userSourceBalance} CCT</span>
              </div>
              <div className="flex justify-between">
                <span className="text-sm text-gray-600">{targetChain.name} 余额:</span>
                <span className="font-semibold">{userTargetBalance} CCT</span>
              </div>
            </div>

            <form onSubmit={(e) => e.preventDefault()}>
              {/* 源链 */}
              <div className="mb-4">
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  从 (源链)
                </label>
                <div className="w-full border border-gray-300 rounded-lg px-4 py-3 flex items-center justify-between bg-gray-50">
                  <span className="font-semibold">{sourceChain.name}</span>
                  <span className="text-sm text-gray-500">{sourceChain.symbol}</span>
                </div>
              </div>

              {/* 切换按钮 */}
              <div className="flex justify-center -my-2 mb-2">
                <button
                  type="button"
                  onClick={handleSwitchDirection}
                  className="bg-blue-100 hover:bg-blue-200 rounded-full p-2 transition-colors"
                >
                  <svg className="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 16V4m0 0L3 8m4-4l4 4m6 0v12m0 0l4-4m-4 4l-4-4" />
                  </svg>
                </button>
              </div>

              {/* 目标链 */}
              <div className="mb-4">
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  到 (目标链)
                </label>
                <div className="w-full border border-gray-300 rounded-lg px-4 py-3 flex items-center justify-between bg-gray-50">
                  <span className="font-semibold">{targetChain.name}</span>
                  <span className="text-sm text-gray-500">{targetChain.symbol}</span>
                </div>
              </div>

              {/* 金额输入 */}
              <div className="mb-6">
                <div className="flex justify-between mb-2">
                  <label className="block text-sm font-medium text-gray-700">
                    转账数量
                  </label>
                  {isConnected && (
                    <button
                      type="button"
                      onClick={handleMaxAmount}
                      className="text-sm text-blue-600 hover:text-blue-700"
                    >
                      最大: {userSourceBalance}
                    </button>
                  )}
                </div>
                <div className="relative">
                  <input
                    type="number"
                    value={amount}
                    onChange={(e) => setAmount(e.target.value)}
                    placeholder="0.0"
                    step="0.000001"
                    className="w-full border border-gray-300 rounded-lg px-4 py-3 focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                  <div className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-600 font-semibold">
                    CCT
                  </div>
                </div>
              </div>

              {/* 错误提示 */}
              {error && (
                <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg">
                  <p className="text-sm text-red-800">{error}</p>
                </div>
              )}

              {/* 操作按钮 */}
              {!isConnected ? (
                <button
                  type="button"
                  className="w-full bg-blue-600 text-white font-semibold py-3 px-6 rounded-lg"
                >
                  连接钱包
                </button>
              ) : isWrongNetwork ? (
                <button
                  type="button"
                  onClick={handleSwitchChain}
                  className="w-full bg-orange-600 hover:bg-orange-700 text-white font-semibold py-3 px-6 rounded-lg transition-colors"
                >
                  切换到 {sourceChain.name}
                </button>
              ) : needsApproval ? (
                <button
                  type="button"
                  onClick={handleApprove}
                  disabled={isApproving || !amount}
                  className="w-full bg-yellow-600 hover:bg-yellow-700 disabled:bg-gray-400 text-white font-semibold py-3 px-6 rounded-lg transition-colors"
                >
                  {isApproving ? '授权中...' : `授权 ${amount || '0'} CCT`}
                </button>
              ) : (
                <button
                  type="button"
                  onClick={handleBridge}
                  disabled={isBridging || !amount}
                  className="w-full bg-blue-600 hover:bg-blue-700 disabled:bg-gray-400 text-white font-semibold py-3 px-6 rounded-lg transition-colors"
                >
                  {isBridging ? '跨链中...' : '发起跨链'}
                </button>
              )}
            </form>

            {/* 费用估算 */}
            <div className="mt-4 p-3 bg-blue-50 rounded-lg">
              <div className="text-xs text-blue-800">
                <div className="flex justify-between mb-1">
                  <span>预估 Gas 费用:</span>
                  <span className="font-semibold">~0.0001 ETH</span>
                </div>
                <div className="flex justify-between">
                  <span>CCIP 跨链费用:</span>
                  <span className="font-semibold">~0.0002 ETH</span>
                </div>
              </div>
            </div>
          </div>

          {/* 右侧：转账历史 */}
          <div>
            <h2 className="text-xl font-bold mb-4">转账记录</h2>

            {transfers.length === 0 ? (
              <div className="bg-white rounded-lg shadow-lg p-12 text-center">
                <svg className="w-16 h-16 text-gray-300 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4" />
                </svg>
                <p className="text-gray-500">暂无跨链记录</p>
                <p className="text-xs text-gray-400 mt-2">发起第一笔跨链转账</p>
              </div>
            ) : (
              <div className="max-h-[600px] overflow-y-auto">
                {transfers.map((transfer, index) => (
                  <TransferRecord
                    key={index}
                    transfer={transfer}
                    sourceChain={sourceChain}
                    targetChain={targetChain}
                  />
                ))}
              </div>
            )}
          </div>
        </div>

        {/* 使用说明 */}
        <div className="mt-6 p-4 bg-gray-50 rounded-lg">
          <h3 className="font-semibold mb-2">CCIP 跨链桥使用说明</h3>
          <ul className="text-sm text-gray-600 space-y-1">
            <li>• 当前支持 Sepolia ↔ Base Sepolia 双向跨链</li>
            <li>• 使用 Chainlink CCIP 协议确保安全可靠</li>
            <li>• 首次跨链需要先授权代币给 CCIP Router</li>
            <li>• 跨链时间约 5-15 分钟，取决于网络状况</li>
            <li>• 需要支付 Gas 费用和 CCIP 跨链费用（约 0.0003 ETH）</li>
            <li>• 可在 CCIP Explorer 查看实时跨链状态</li>
          </ul>
        </div>
      </div>
    </div>
  )
}
