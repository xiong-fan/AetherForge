// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/Swap.sol";
import "../src/StakePool.sol";
import "../src/TokenA.sol";
import "../src/TokenB.sol";
import "../src/RewardToken.sol";

/**
 * @title TestStakingFlow
 * @dev Complete staking flow test:
 * 1. Check Token A and Token B balance
 * 2. Mint tokens if balance is insufficient
 * 3. Add liquidity to get LP Token
 * 4. Stake LP Token
 * 5. Wait and check rewards
 * 6. Unstake
 */
contract TestStakingFlow is Script {
    // Load addresses from .env (using correct checksums)
    address constant REWARD_TOKEN_ADDRESS = 0xb09c7d0757Ed382E2E0F03477671307Dcf7cC30E;
    address constant TOKEN_A_ADDRESS = 0x8a88b830915AEA048Ebf8340ACa47E21b8E342B4;
    address constant TOKEN_B_ADDRESS = 0x2b79645f2Be73db5C001397BA261489DD5D25294;
    address constant SWAP_ADDRESS = 0x6bc3531769F05eA1b99A92c8fb5EB557c3715801;
    address constant STAKE_POOL_ADDRESS = 0x1AD9AF9eFD7506666200b0748CE9761ADF981417;

    // Test amounts
    uint256 constant REQUIRED_AMOUNT = 100 * 10**18; // 100 tokens each
    uint256 constant STAKE_AMOUNT = 10 * 10**18;     // Stake 10 LP

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Starting Complete Staking Flow Test ===");
        console.log("Test Account:", deployer);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Check and prepare Token A and Token B
        TokenA tokenA = TokenA(TOKEN_A_ADDRESS);
        TokenB tokenB = TokenB(TOKEN_B_ADDRESS);
        Swap swap = Swap(SWAP_ADDRESS);
        StakePool stakePool = StakePool(STAKE_POOL_ADDRESS);

        uint256 balanceA = tokenA.balanceOf(deployer);
        uint256 balanceB = tokenB.balanceOf(deployer);

        console.log("Step 1: Check token balances");
        console.log("Token A balance:", balanceA / 10**18, "tokens");
        console.log("Token B balance:", balanceB / 10**18, "tokens");
        console.log("Required amount:", REQUIRED_AMOUNT / 10**18, "tokens");

        // Mint tokens if balance is insufficient
        if (balanceA < REQUIRED_AMOUNT) {
            console.log("");
            console.log("Token A balance insufficient, minting...");
            uint256 mintAmount = REQUIRED_AMOUNT - balanceA + 100 * 10**18; // Mint extra

            // Check remaining mint amount
            uint256 remainingMint = tokenA.remainingMintAmount(deployer);
            console.log("Remaining mintable Token A:", remainingMint / 10**18, "tokens");

            if (remainingMint >= mintAmount) {
                tokenA.mint(mintAmount);
                console.log("Successfully minted Token A:", mintAmount / 10**18, "tokens");
            } else if (remainingMint > 0) {
                console.log("Warning: Can only mint", remainingMint / 10**18, "tokens (per-address limit)");
                tokenA.mint(remainingMint);
            } else {
                console.log("Error: This address has reached Token A mint limit");
                revert("Token A mint limit exceeded");
            }
        } else {
            console.log("Token A balance sufficient");
        }

        if (balanceB < REQUIRED_AMOUNT) {
            console.log("");
            console.log("Token B balance insufficient, minting...");
            uint256 mintAmount = REQUIRED_AMOUNT - balanceB + 100 * 10**18;

            // Check remaining mint amount
            uint256 remainingMint = tokenB.remainingMintAmount(deployer);
            console.log("Remaining mintable Token B:", remainingMint / 10**18, "tokens");

            if (remainingMint >= mintAmount) {
                tokenB.mint(mintAmount);
                console.log("Successfully minted Token B:", mintAmount / 10**18, "tokens");
            } else if (remainingMint > 0) {
                console.log("Warning: Can only mint", remainingMint / 10**18, "tokens (per-address limit)");
                tokenB.mint(remainingMint);
            } else {
                console.log("Error: This address has reached Token B mint limit");
                revert("Token B mint limit exceeded");
            }
        } else {
            console.log("Token B balance sufficient");
        }

        // Recheck balances
        balanceA = tokenA.balanceOf(deployer);
        balanceB = tokenB.balanceOf(deployer);
        console.log("");
        console.log("Current Token A balance:", balanceA / 10**18, "tokens");
        console.log("Current Token B balance:", balanceB / 10**18, "tokens");

        // Step 2: Approve Swap contract
        console.log("");
        console.log("Step 2: Approve Swap contract");

        if (tokenA.allowance(deployer, SWAP_ADDRESS) < REQUIRED_AMOUNT) {
            console.log("Approving Token A to Swap...");
            tokenA.approve(SWAP_ADDRESS, type(uint256).max);
            console.log("Token A approved");
        } else {
            console.log("Token A already has sufficient allowance");
        }

        if (tokenB.allowance(deployer, SWAP_ADDRESS) < REQUIRED_AMOUNT) {
            console.log("Approving Token B to Swap...");
            tokenB.approve(SWAP_ADDRESS, type(uint256).max);
            console.log("Token B approved");
        } else {
            console.log("Token B already has sufficient allowance");
        }

        // Step 3: Add liquidity
        console.log("");
        console.log("Step 3: Add liquidity");
        console.log("LP balance before adding liquidity:", swap.balanceOf(deployer) / 10**18, "LP");
        console.log("Adding liquidity: Token A =", REQUIRED_AMOUNT / 10**18, ", Token B =", REQUIRED_AMOUNT / 10**18);

        uint256 liquidity = swap.addLiquidity(REQUIRED_AMOUNT, REQUIRED_AMOUNT);

        console.log("LP balance after adding liquidity:", swap.balanceOf(deployer) / 10**18, "LP");
        console.log("Received LP Token:", liquidity / 10**18, "LP");
        console.log("Liquidity added successfully");

        // Step 4: Approve and stake LP Token
        console.log("");
        console.log("Step 4: Stake LP Token to StakePool");

        if (swap.allowance(deployer, STAKE_POOL_ADDRESS) < STAKE_AMOUNT) {
            console.log("Approving LP Token to StakePool...");
            swap.approve(STAKE_POOL_ADDRESS, type(uint256).max);
            console.log("LP Token approved");
        }

        console.log("Staked amount before:", stakePool.stakedBalance(deployer) / 10**18, "LP");
        console.log("Staking", STAKE_AMOUNT / 10**18, "LP Token...");
        stakePool.stake(STAKE_AMOUNT);
        console.log("Staked amount after:", stakePool.stakedBalance(deployer) / 10**18, "LP");
        console.log("Staking successful");

        vm.stopBroadcast();

        // Step 5: Check rewards (wait for some time)
        console.log("");
        console.log("Step 5: Waiting for rewards to accumulate...");
        console.log("Note: In real environment, rewards accumulate over time");
        console.log("StakePool reward rate: 1 token/second");

        // In script we cannot actually wait, but we can query current rewards
        uint256 earned = stakePool.earned(deployer);
        console.log("Current pending rewards:", earned / 10**18, "tokens");

        if (earned > 0) {
            console.log("");
            console.log("Found rewards, claiming...");
            vm.broadcast(deployerPrivateKey);
            stakePool.claimReward();
            console.log("Rewards claimed");
        } else {
            console.log("");
            console.log("Rewards are 0 (just staked, too short time)");
            console.log("Suggestion: Wait a few minutes then run unstake script");
        }

        // Step 6: Unstake (optional, commented out to keep staked status)
        console.log("");
        console.log("Step 6: Unstake (commented out)");
        console.log("To unstake, uncomment the code below:");
        console.log("// stakePool.withdraw(STAKE_AMOUNT);");

        /*
        vm.broadcast(deployerPrivateKey);
        console.log("Unstaking", STAKE_AMOUNT / 10**18, "LP Token...");
        stakePool.withdraw(STAKE_AMOUNT);
        console.log("Unstaking successful");

        uint256 finalStaked = stakePool.stakedBalance(deployer);
        console.log("Final staked amount:", finalStaked / 10**18, "LP");
        */

        // Final status
        console.log("");
        console.log("=== Final Status ===");
        console.log("Token A balance:", tokenA.balanceOf(deployer) / 10**18);
        console.log("Token B balance:", tokenB.balanceOf(deployer) / 10**18);
        console.log("LP Token balance:", swap.balanceOf(deployer) / 10**18);
        console.log("Staked amount:", stakePool.stakedBalance(deployer) / 10**18);
        console.log("Pending rewards:", stakePool.earned(deployer) / 10**18);

        console.log("");
        console.log("=== Test Completed ===");
        console.log("Hint: Run the following command to check staking status:");
        console.log("cast call", STAKE_POOL_ADDRESS, '"stakedBalance(address)(uint256)"', deployer);
        console.log("");
        console.log("Check rewards:");
        console.log("cast call", STAKE_POOL_ADDRESS, '"earned(address)(uint256)"', deployer);
    }
}
