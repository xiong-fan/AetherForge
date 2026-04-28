// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Farm} from "../src/Farm.sol";
import {Token} from "../src/Token.sol";

contract FarmTest is Test {

    Farm public farm;
    address public deployer;
    address public user1 = 0xB99B24a22fc59280A0b7833370A53F42dB7fc8d6;
    address public rewardAddress = 0x306e00D623df7328a933826edd118B16998895ee;
    address public constant LPAddress = 0xf6e00bD0Dfa3a4d2D8d20FB8C0846068d5e1B72A;

    function setUp() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(privateKey);
        vm.startPrank(deployer);
        farm = new Farm(rewardAddress, 1 * 10**18);
        farm.addPool(LPAddress, 2000);
        farm.addPool(LPAddress, 4000);
        Token(rewardAddress).mint(address(farm), 20000*10**18);
        Token(rewardAddress).balanceOf(address(farm));
        vm.stopPrank();

        console.log("Test deployer address:", deployer);
        console.log("Test farm address:", address(farm));
    }

    function test_harvest() public {
        vm.startPrank(user1);
        IERC20(LPAddress).approve(address(farm), 600*10**18);
        farm.deposit(1, 300*10**18);
        

         // 用 IERC20 类型接收 lpToken
        (IERC20 lpToken, uint256 allocPoint, uint256 lastRewardTime, uint256 accRewardPerShare, uint256 totalStaked) = farm.poolInfo(1);

        console.log("=== Pool Info ===");
        console.log("lpToken address:", address(lpToken));  // 转换为 address 打印
        console.log("allocPoint:", allocPoint);
        console.log("lastRewardTime:", lastRewardTime);
        console.log("accRewardPerShare:", accRewardPerShare);
        console.log("totalStaked:", totalStaked);
        
        // 读取 User Info
        (uint256 amount, uint256 rewardDebt) = farm.userInfo(1, user1);
        
        console.log("=== User Info ===");
        console.log("user amount:", amount);
        console.log("user rewardDebt:", rewardDebt);
        

        // 等待一段时间让奖励累积
        vm.warp(block.timestamp + 600); // 前进10分钟
        
        // 更新池子
        farm.updatePool(1);
        

        // 用 IERC20 类型接收 lpToken
        (lpToken, allocPoint, lastRewardTime, accRewardPerShare, totalStaked) = farm.poolInfo(1);

        console.log("=== update Pool Info ===");
        console.log("lpToken address:", address(lpToken));  // 转换为 address 打印
        console.log("allocPoint:", allocPoint);
        console.log("lastRewardTime:", lastRewardTime);
        console.log("accRewardPerShare:", accRewardPerShare);
        console.log("totalStaked:", totalStaked);


        // 查看待领取奖励
        uint256 pending = farm.pendingReward(1, user1);
        console.log("pending reward:", pending);
        
        // 领取奖励
        farm.harvest(1);
        console.log("Harvest completed");

        uint256 drtAmount = Token(rewardAddress).balanceOf(user1);
        console.log("drt amount of user1:", drtAmount);

        vm.stopPrank();

    }
}
