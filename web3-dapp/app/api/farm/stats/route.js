import { NextResponse } from 'next/server'
import { FARM_ABI } from '@/lib/abis/farm'
import { JsonRpcProvider, Contract } from 'ethers'

/**
 * GET /api/farm/stats
 *
 * Returns farming statistics and historical APY data
 *
 * Response fields:
 * - totalValueLocked: Total TVL across all farms (string)
 * - totalRewardsDistributed: Total rewards distributed (string)
 * - activeUsers: Number of active farmers (number)
 * - pools: Array of farm pool stats
 *   - poolId: Pool ID (number)
 *   - name: Pool name (string)
 *   - lpToken: LP token symbol (string)
 *   - tvl: Pool TVL (string)
 *   - apy: Current APY (number)
 *   - allocPoint: Allocation points (number)
 *   - totalStaked: Total LP staked (string)
 * - apyHistory: Historical APY data for charting
 *   - ts: Timestamp (number)
 *   - apy: APY at that time (number)
 *   - poolId: Pool ID (number)
 * - source: Data source - "chain" or "mock" (string)
 * - timestamp: Response timestamp (string)
 */

// Generate mock farm stats
function generateMockFarmStats() {
  const now = Date.now()
  const apyHistory = []

  // Generate 30 days of APY history for multiple pools
  for (let day = 30; day >= 0; day--) {
    const ts = now - (day * 24 * 60 * 60 * 1000)

    // Pool 0 APY
    apyHistory.push({
      ts,
      apy: 120 + Math.sin(day * 0.3) * 15 + (Math.random() - 0.5) * 10,
      poolId: 0
    })

    // Pool 1 APY
    apyHistory.push({
      ts,
      apy: 200 + Math.cos(day * 0.4) * 25 + (Math.random() - 0.5) * 15,
      poolId: 1
    })

    // Pool 2 APY
    apyHistory.push({
      ts,
      apy: 80 + Math.sin(day * 0.2) * 10 + (Math.random() - 0.5) * 8,
      poolId: 2
    })
  }

  return {
    totalValueLocked: '5500000',
    totalRewardsDistributed: '12500000',
    activeUsers: 1247,
    pools: [
      {
        poolId: 0,
        id: 0, // Add id field for consistency
        name: 'TKA-TKB LP Farm',
        lpToken: 'TKA-TKB LP',
        lpTokenAddress: process.env.NEXT_PUBLIC_SWAP_ADDRESS, // Swap contract is the LP token
        tvl: '3200000',
        apy: 125.5,
        allocPoint: 100,
        totalStaked: '1500000',
        rewardPerSecond: '3000000000000000000', // 3 tokens per second
        address: process.env.NEXT_PUBLIC_FARM_ADDRESS || '0x0000000000000000000000000000000000000000'
      },
      {
        poolId: 1,
        id: 1,
        name: 'TKA-USDC LP Farm',
        lpToken: 'TKA-USDC LP',
        lpTokenAddress: '0x0000000000000000000000000000000000000000', // Not deployed
        tvl: '1800000',
        apy: 210.3,
        allocPoint: 150,
        totalStaked: '800000',
        rewardPerSecond: '5000000000000000000' // 5 tokens per second
      },
      {
        poolId: 2,
        id: 2,
        name: 'TKB-USDC LP Farm',
        lpToken: 'TKB-USDC LP',
        lpTokenAddress: '0x0000000000000000000000000000000000000000', // Not deployed
        tvl: '500000',
        apy: 85.7,
        allocPoint: 50,
        totalStaked: '250000',
        rewardPerSecond: '1500000000000000000' // 1.5 tokens per second
      }
    ],
    apyHistory: apyHistory.map(item => ({
      ...item,
      apy: parseFloat(item.apy.toFixed(2))
    })),
    source: 'mock',
    timestamp: new Date().toISOString()
  }
}

// Try to fetch from chain (placeholder for future implementation)
async function fetchChainFarmStats() {
  // TODO: Implement chain reading
  console.log('fetchChainFarmStats into')
  const provider = new JsonRpcProvider(process.env.NEXT_PUBLIC_RPC_URL_SEPOLIA)
  console.log('provider', provider)
  const farmContract = new Contract(process.env.NEXT_PUBLIC_FARM_ADDRESS, FARM_ABI, provider)
  console.log('farmContract', farmContract)
  const poolLength = await farmContract.poolLength()
  console.log('poolLength', poolLength)
  const pools = []
  for (let i = 0; i < Number(poolLength); i++) {  // ← BigInt 转 Number
    const poolInfo = await farmContract.poolInfo(i)
    
    console.log('poolInfo', poolInfo)
    // ← 将 BigInt 字段转换为字符串或数字
    pools.push({
      lpTokenAddress: poolInfo.lpToken,           // address 是 string，不需要转
      allocPoint: Number(poolInfo.allocPoint),        // BigInt → Number
      lastRewardTime: Number(poolInfo.lastRewardTime), // BigInt → Number
      rewardPerSecond: poolInfo.accRewardPerShare.toString(), // BigInt → string
      totalStaked: poolInfo.totalStaked.toString(),    // BigInt → string

      poolId: i,
      id: i, // Add id field for consistency
      name: 'DAN-USDC LP Farm',
      lpToken: 'DAN-USDC LP',
      tvl: '3200000',
      apy: 125.5,
      address: process.env.NEXT_PUBLIC_FARM_ADDRESS || '0x0000000000000000000000000000000000000000'
      
    })
  }
  
  // 如果有其他 BigInt 字段，也一并转换
  const rewardPerSecond = await farmContract.rewardPerSecond()
  const totalAllocPoint = await farmContract.totalAllocPoint()
  
  const stats = {
    totalValueLocked: '5500000',
    totalRewardsDistributed: '12500000',
    activeUsers: 1247,
    pools,
    rewardPerSecond: rewardPerSecond.toString(),
    totalAllocPoint: Number(totalAllocPoint),
    source: 'chain',
    timestamp: new Date().toISOString(),
  }
  console.log('stats', stats)
  return stats // Return null to fallback to mock data
}

export async function GET() {
  try {
    // Try to fetch from chain first
    const chainData = await fetchChainFarmStats()

    if (chainData) {
      return NextResponse.json(chainData)
    }

    // Fallback to mock data
    const mockData = generateMockFarmStats()
    return NextResponse.json(mockData)

  } catch (error) {
    console.error('Error fetching farm stats:', error)
    return NextResponse.json(
      { error: 'Failed to fetch farm stats' },
      { status: 500 }
    )
  }
}
